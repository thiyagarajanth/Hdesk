module IssuesControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
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

    end
  end
end



