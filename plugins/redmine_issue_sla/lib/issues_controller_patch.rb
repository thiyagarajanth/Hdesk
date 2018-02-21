module IssuesControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      before_filter :authorize, :except => [:index, :ticket_rating, :avg_rating, :check_rating]

      def index
        retrieve_query
        sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
        sort_update(@query.sortable_columns)
        @query.sort_criteria = sort_criteria.to_a
        state = params[:f].present? ? (params[:f] & ['approved_by', 'resolved_by']).any? : false
        if @query.valid?
          case params[:format]
            when 'csv', 'pdf'
              @limit = Setting.issues_export_limit.to_i
              if params[:columns] == 'all'
                @query.column_names = @query.available_inline_columns.map(&:name)
              end
            when 'atom'
              @limit = Setting.feeds_limit.to_i
            when 'xml', 'json'
              @offset, @limit = api_offset_and_limit
              @query.column_names = %w(author)
            else
              @limit = per_page_option
          end

          @issue_count = @query.issue_count
            @issue_pages = Redmine::Pagination::Paginator.new @issue_count, @limit, params['page']
          @offset ||= @issue_pages.offset
          @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
                                  :order => sort_clause,
                                  :offset => @offset,
                                  :visible => state,
                                  :limit => @limit)
          @issue_count_by_group = @query.issue_count_by_group
          if params[:period_type].present? || params[:rated_for].present?
            @sla_issues = []
            sla_helper = Object.new.extend(SlaReportsHelper)
            if params[:period_type] == '2' && params[:rated_for].present?
              date_range = ''
              date_range = "and created_at >= '#{params[:from]+' 00:00:00'}'" if params[:from].present?
              date_range = date_range + "and created_at <= '#{params[:to]+' 23:59:59'}'" if params[:to].present?
              issue_ids = UserRating.where("rated_for = #{params[:rated_for]} " + date_range ).map(&:issue_id)
            elsif params[:period_type] == '1' && params[:rated_for].present?
              issue_ids = sla_helper.get_user_rating_issues(params, @project)
            else
              issue_ids = sla_helper.get_issues_list(params)
            end
            if issue_ids.present?
              @issues = Issue.find(issue_ids)
              @issue_count = @issues.count
              @issue_pages = Redmine::Pagination::Paginator.new @issue_count, @limit, params['page']
              @offset ||= @issue_pages.offset
            end
          end
          respond_to do |format|
            format.html { render :template => 'issues/index', :layout => !request.xhr? }
            format.api  {
              Issue.load_visible_relations(@issues) if include_in_api_response?('relations')
            }
            format.atom { render_feed(@issues, :title => "#{@project || Setting.app_title}: #{l(:label_issue_plural)}") }
            format.csv  { send_data(query_to_csv(@issues, @query, params), :type => 'text/csv; header=present', :filename => 'issues.csv') }
            format.pdf  { send_data(issues_to_pdf(@issues, @project, @query), :type => 'application/pdf', :filename => 'issues.pdf') }
          end
        else
          respond_to do |format|
            format.html { render(:template => 'issues/index', :layout => !request.xhr?) }
            format.any(:atom, :csv, :pdf) { render(:nothing => true) }
            format.api { render_validation_errors(@query) }
          end
        end
      rescue ActiveRecord::RecordNotFound
        render_404
      end


      def show
        @journals = @issue.journals.includes(:user, :details).reorder("#{Journal.table_name}.id ASC").all
        @journals.each_with_index {|j,i| j.indice = i+1}
        @journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
        Journal.preload_journals_details_custom_fields(@journals)
        # TODO: use #select! when ruby1.8 support is dropped
        @journals.reject! {|journal| !journal.notes? && journal.visible_details.empty?}
        @journals.reverse! if User.current.wants_comments_in_reverse_order?

        @changesets = @issue.changesets.visible.preload(:repository, :user).to_a
        @changesets.reverse! if User.current.wants_comments_in_reverse_order?

        @relations = @issue.relations.select {|r| r.other_issue(@issue) && r.other_issue(@issue).visible? }
        @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
        @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
        @priorities = IssuePriority.active
        @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
        @relation = IssueRelation.new

        if @issue.project.users.count > 0
          @available_access_users = @issue.project.users.sort
        end

        respond_to do |format|
          format.html {
            retrieve_previous_and_next_issue_ids
            render :template => 'issues/show'
          }
          format.api
          format.atom { render :template => 'journals/index', :layout => false, :content_type => 'application/atom+xml' }
          format.pdf  {
            pdf = issue_to_pdf(@issue, :journals => @journals)
            send_data(pdf, :type => 'application/pdf', :filename => "#{@project.identifier}-#{@issue.id}.pdf")
          }
        end
      end


      def new
        data1 = Issue.where(:author_id => User.current.id, :project_id => Project.find_by_identifier(params[:project_id]).id)
        data = data1.collect{|rec|rec if rec.status.present? && rec.status.name=='Resolved'} 
        helper = Object.new.extend(SlaTimeHelper)
        state = []
        data.compact.each do |rec|
          state << helper.get_resolved_duration(rec)
        end
        if @issue.project.users.count > 0
          @available_access_users = @issue.project.users.sort
        end
        respond_to do |format|
          if !state.include?(true)
            format.html { render :action => 'new', :layout => !request.xhr? }
          else
            flash[:error] = "Please close your 'Resolved' ticket to continue with New tickets."
            format.html { redirect_to  :controller => 'issues', :action => 'index',
                        "set_filter"=>"1", "f"=>["status_id", "author_id", ""], "op"=>{"status_id"=>"=", "author_id"=>"="},
                        "v"=>{"status_id"=>["3"], "author_id"=>["me"]},
                        "c"=>["author", "subject", "assigned_to", "priority", "status", "updated_on", "created_on", "tracker", "project"], "group_by"=>""

            }
          end
        end
      end

      def ticket_rating(issue, rating)
        # issue = Issue.find(params[:issue_id])
        rate =  UserRating.find_or_initialize_by_issue_id(issue.id)
        # rate = UserRating.new(:issue_id => issue.id) if !rate.present?
        user_id = Journal.find_by_sql("select user_id from journals as j
join journal_details as jd on j.id=jd.journal_id and j.journalized_id=#{issue.id} and
jd.prop_key='status_id' and jd.value=(select id from issue_statuses where name='Resolved')").map(&:user_id).first
        rate.rated_for = user_id
        rate.rated_by = issue.author_id
        rate.project_id = issue.project_id
        rate.rating = rating
        rate.save
      end

      def check_rating
        result = UserRating.find_by_sql("select COALESCE(sum(rating),0) as rating from user_ratings where issue_id =#{params[:issue_id]}").map(&:rating).last
        render :json => {data: result}
      end
      def avg_rating
        if params[:project_id].present?
          project = Project.find_by_identifier(params[:project_id])
          if project.present?
            cond = " and project_id="+project.id.to_s
          else
            cond = ''
          end
        end
        count,avg = UserRating.find_by_sql("select count(*) as count, COALESCE(round(avg(rating),2),0) as avg from user_ratings where rated_for = #{params[:user_id]}" + cond).map{|x|[x.count, x.avg.to_f]}.last
        # rating = UserRating.where(:rated_for => params[:user_id])
        # avg = rating.average(:rating) rescue 0
        # avg = avg.present? ? avg.round(2) : 0
        result = {:count => count, :avg => avg}
        render :json => {result: result}
      end
      
      def create

        helper = Object.new.extend(CategoryApprovalConfigsHelper)
        if !helper.user_inia_project_ids.include?(params[:tickets][:project_id].to_i)
          flash[:alert] = "Requested project not assigned to you, Please contact your manager."
          render :action => 'new'
          return
        end

        ticket = params[:tickets]
        @tag_id = 0
        call_hook(:controller_issues_new_before_save, { :params => params, :issue => @issue })
        @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
        # Issue.skip_callback(:create, :after, :send_notification)
        has_ticket = Redmine::Plugin.registered_plugins.keys.include?(:ticketing_approval_system)
        if has_ticket
          project = IniaProject.find(params[:tickets][:project_id])
          needed_approval = ProjectCategory.find(ticket[:category_id]).need_approval
          if needed_approval
            subject = params[:issue][:subject]
            text = params[:tickets][:task_name]
            @issue.subject= text
            tag = TicketTag.find(subject)
            approval_infos = tag.ticket_approvals
            helper = Object.new.extend(CategoryApprovalConfigsHelper)
            have_approval = @issue.get_first_approval(project, tag)
            @issue.assign_params_from_controller(tag)
            @tag_id = tag.id
          end
        end
        approval_users = ApprovalRoleUser.where(:project_id =>@project.id,
                        :inia_project_id => project.id).map(&:user_id) rescue ''
        inactive = User.find(approval_users).map(&:status).include?(3)
              
        if params[:issue][:user_access_user_ids].present?

          @issue.access_users = params[:issue][:user_access_user_ids]
        end
        if (!needed_approval || (approval_infos.present? && have_approval) || !approval_infos.present?) && !inactive

          if @issue.save
            # raise

            if needed_approval
              IssueTicketTag.create(:issue_id => @issue.id,:category_id => ticket[:category_id], :inia_project_id => project.id, :ticket_tag_id => tag.id)
            else
              IssueTicketTag.create(:issue_id => @issue.id,:category_id => ticket[:category_id], :inia_project_id => project.id, :ticket_tag_id => nil)
            end
            if has_ticket && @issue.tracker.core_fields.include?('approval_workflow')
              project_id = ticket[:project_id].present? ? IniaProject.find(ticket[:project_id]).id : project.id
              if needed_approval && tag.present? && approval_infos.count >= 1
                @issue.ticket_need_approval(approval_infos, params)
                # Mailer.deliver_issue_add(@issue)
              else
                if @issue.ticket_tag.present? && @issue.ticket_tag.have_agreement == true
                  status = IssueStatus.find_or_initialize_by_name('Accept Agreement')
                  status.save
                  @issue.status_id = status.id
                  @issue.assigned_to_id = @issue.author_id
                  @issue.init_journal(User.current, 'Please accept the Agreement for further action.')
                  @issue.save(validate: false)
                else
                  default_assignee =  DefaultAssigneeSetup.find_by_project_id_and_tracker_id(@issue.project_id, @issue.tracker_id)
                  default_assignee = default_assignee.present? ? default_assignee : DefaultAssigneeSetup.new
                  @issue.assigned_to_id = default_assignee.default_assignee_to
                  # journal =  Journal.create(journalized_id: @issue.id, journalized_type: 'Issue', user_id: User.current.id,notes: '.' )
                  old_status = IssueStatus.find_by_name('New')
                  @issue.init_journal(User.current, '')
                  status = IssueStatus.find_by_name('open')
                  # JournalDetail.create(journal_id: journal.id, property: "attr", prop_key: "status_id", old_value: old_status.id, value: status.id)
                  @issue.status_id = status.id
                  @issue.save
                end
                # Mailer.deliver_issue_add(@issue)
              end
            end
            p @issue.push_external_tag_tickets('New')
            call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
            respond_to do |format|
              format.html {
                render_attachment_warning_if_needed(@issue)
                flash[:notice] = l(:notice_issue_successful_create, :id => view_context.link_to("##{@issue.id}", issue_path(@issue), :title => @issue.subject))
                if params[:continue]
                  attrs = {:tracker_id => @issue.tracker, :parent_issue_id => @issue.parent_issue_id}.reject {|k,v| v.nil?}
                  redirect_to new_project_issue_path(@issue.project, :issue => attrs)
                else
                  redirect_to issue_path(@issue)
                end
              }
              format.api  { render :action => 'show', :status => :created, :location => issue_url(@issue) }
            end
            return
          else
            respond_to do |format|
              format.html { render :action => 'new' }
              format.api  { render_validation_errors(@issue) }
            end
          end
        else
          respond_to do |format|
            flash[:alert] = "Approval workflow is missing for next level. Please contact your project manager or IT Ops Team."
              format.html { render :action => 'new' }
              format.api  { render_validation_errors(@issue) }
            end
        end
        Issue.set_callback(:create, :after, :send_notification)
      end
      
      def update
        sla_time_helper = Object.new.extend(SlaTimeHelper)
        # change_status = false
        if sla_time_helper.redmine_issue_sla_enabled(@issue)
          sla_time_helper.duration_of_ticket(params[:id], params[:issue][:status_id], params[:old_status_id])
          # change_status = true if @issue.status_id.to_s != params[:issue][:status_id]
        end        
        name1 =  @issue.status.name
        return unless update_issue_from_params
        @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
        saved = false
        begin
          saved = save_issue_with_child_records
        rescue ActiveRecord::StaleObjectError
          @conflict = true
          if params[:last_journal_id]
            @conflict_journals = @issue.journals_after(params[:last_journal_id]).all
            @conflict_journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
          end
        end
        name2 = @issue.status.name
        if @issue.is_system_created && name1 != name2 && (name2 == 'Resolved' || name2 == 'Rejected')
          @issue.send_notification_to_auto_tickets
        end
        if params[:approval_state].present?
          approval_infos = @issue.ticket_tag.ticket_approvals
          helper = Object.new.extend(CategoryApprovalConfigsHelper)
          @issue.ticket_need_approval(approval_infos, params) if params[:approval_state]=='true'
          helper.reject_ticket(@issue, approval_infos, params) if params[:approval_state]=='false'
        end

        if @issue.ticket_tag.present?
          @issue.assign_params_from_controller(@issue.ticket_tag)
          @tag_id = @issue.ticket_tag.id
        end
        if saved && @issue.save
          if params[:rating].present?
            ticket_rating(@issue, params[:rating])
          end
          if params[:issue][:status_id] .present? && IssueStatus.find(params[:issue][:status_id]).name == 'Resolved'
            details = IssueDetail.find_or_initialize_by_issue_id(@issue.id)
            details.resolved_by = User.current
            hr = TimeEntry.where(:issue_id => @issue.id).group('issue_id').sum('hours').values[0]
            sla_hours = @issue.issue_sla.to_f
            hr = hr.present? ? hr : 0
            status = sla_hours >= hr ? true : false
            details.sla_duration = sla_hours
            details.resolution_time = hr
            details.is_met_sla=status
            details.save
          end
          param_priority = params[:issue][:priority_id]
          active_sla = sla_time_helper.redmine_issue_sla_enabled(@issue)
          # if active_sla && sla_time_helper.check_sla_hours(@issue) && change_status && @issue.sla_times.present?&& @issue.sla_times.last.old_status.present? && @issue.sla_times.last.old_status.sla_timer == 'start'
          #   dur = @issue.sla_times.last.pre_status_duration
          #   # total_dur = (dur*100)/60
          #   hh,mm = dur.divmod(100)
          #   mm = mm.to_i.to_s.present? ? (mm.to_i.to_s.size > 1 ? mm.to_i : "0#{mm.to_i}") : mm.to_i
          #   s = TimeEntry.new(:project_id => @issue.project.id, :issue_id => @issue.id, :hours => "#{hh}.#{mm}", :comments => sla_time_helper.retun_time_entry_msg(@issue.sla_times.last) , :activity_id => 8 , :spent_on => Date.today)
          #   s.user_id =  @issue.sla_times.last.user_id
          #   s.save
          # end
          if param_priority.present? && active_sla
            priority = IssuePriority.find(param_priority)
            sla_rec = IssueSla.where(:tracker_id => @issue.tracker.id, :project_id => @issue.project.id, :priority_id => priority.id)
            @issue.update_attributes(:estimated_hours => sla_rec.last.allowed_delay, :priority_id => param_priority) #if @issue.estimated_hours == 0
          end
          render_attachment_warning_if_needed(@issue)
          flash[:notice] = l(:notice_successful_update) unless @issue.current_journal.new_record?

          respond_to do |format|
            format.html { redirect_back_or_default issue_path(@issue) }
            format.api  { render_api_ok }
          end
        else
          respond_to do |format|
            format.html { render :action => 'edit' }
            format.api  { render_validation_errors(@issue) }
          end
        end
      end


      def update_form1
        tracker_id =  params[:issue][:tracker_id]
        project = Project.find_by_identifier(params[:project_id])
        tracker = project.trackers.find(tracker_id.to_i)
        @trackp = []
        @tracks = []
        tracker_status =  IssueSlaStatus.where(:project_id => project.id, :tracker_id => tracker.id)
        tracker_sla =  IssueSla.where(:project_id => project.id, :tracker_id => tracker.id)
        tracker_sla.collect{|rec| @trackp << [rec.priority.id, rec.priority.name]}
        tracker_status.collect{|rec| @tracks << [rec.issue_status.id, rec.issue_status.name]}
        respond_to do |format|
          format.js { render :json => [@trackp, @tracks] }
        end
      end

      def save_issue_with_child_records
        Issue.transaction do
          if params[:reason].present?
            details = IssueDetail.find_or_initialize_by_issue_id(@issue.id)
            details.remarks = params[:reason]
            details.save
          end
          condition = params[:time_entry] && (params[:time_entry][:hours].present? || params[:time_entry][:comments].present?)
          if condition && User.current.allowed_to?(:log_time, @issue.project)
            time_entry = @time_entry || TimeEntry.new
            time_entry.project = @issue.project
            time_entry.issue = @issue
            time_entry.user = User.current
            time_entry.spent_on = User.current.today
            time_entry.attributes = params[:time_entry]
            @issue.time_entries << time_entry
            @new_er =  time_entry.errors.messages
          end
          if IssueStatus.find(@issue.status_id).name == 'Resolved' && !condition
            time_entry = @time_entry || TimeEntry.new
            time_entry.check_sla_met_or_not
            # if !@issue.issue_detail.remarks.present?
            #   time_entry.errors.add(:hours, "exceeding SLA time limit for this issue, So please give a reason for not met SLA.")
            #   @new_er =  time_entry.errors.messages
            # end
            @new_er =  time_entry.errors.messages
          end
          # p '===== 1 ===='
          # p @new_er
          # p '===='
          # p @issue
          # raise
          call_hook(:controller_issues_edit_before_save, { :params => params, :issue => @issue, :time_entry => time_entry, :journal => @issue.current_journal})
          if @new_er.present? && @new_er.size > 0
            @issue.errors.messages
          end
          if !@new_er.present? || @new_er.size < 1 && @issue.save
            call_hook(:controller_issues_edit_after_save, { :params => params, :issue => @issue, :time_entry => time_entry, :journal => @issue.current_journal})
          else
            raise ActiveRecord::Rollback
          end
        end
      end

      def bulk_edit
        @issues.sort!
        @copy = params[:copy].present?
        @notes = params[:notes]

        if User.current.allowed_to?(:move_issues, @projects)
          @allowed_projects = Issue.allowed_target_projects_on_move
          if params[:issue]
            @target_project = @allowed_projects.detect {|p| p.id.to_s == params[:issue][:project_id].to_s}
            if @target_project
              target_projects = [@target_project]
            end
          end
        end
        target_projects ||= @projects

        if @copy
          @available_statuses = [IssueStatus.default]
        else
          @available_statuses = @issues.map{|x| x.new_statuses_allowed_to.map{|y| y if ((y.name != 'Closed' && !User.current.admin?)||User.current.admin? )}.compact }.reduce(:&)
          # @available_statuses = @issues.map(&:new_statuses_allowed_to).reduce(:&)
        end
        @custom_fields = target_projects.map{|p|p.all_issue_custom_fields.visible}.reduce(:&)
        @assignables = target_projects.map(&:assignable_users).reduce(:&)
        @trackers = target_projects.map(&:trackers).reduce(:&)
        @versions = target_projects.map {|p| p.shared_versions.open}.reduce(:&)
        @categories = target_projects.map {|p| p.issue_categories}.reduce(:&)
        if @copy
          @attachments_present = @issues.detect {|i| i.attachments.any?}.present?
          @subtasks_present = @issues.detect {|i| !i.leaf?}.present?
        end

        @safe_attributes = @issues.map(&:safe_attribute_names).reduce(:&)

        @issue_params = params[:issue] || {}
        @issue_params[:custom_field_values] ||= {}
      end

    end
  end
end



