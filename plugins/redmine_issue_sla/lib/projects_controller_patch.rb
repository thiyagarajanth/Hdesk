module ProjectsControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      
      skip_before_filter :find_project,:authorize,:only=>[:datatable_values]
      menu_item :settings, :only => :settings

      def modules
        @project.enabled_module_names = params[:enabled_module_names]
        if !@project.enabled_modules.map(&:name).include?('redmine_issue_sla')
          @project.issue_slas.destroy_all if @project.issue_slas.present?
          @project.issue_sla_statuses.destroy_all if @project.issue_sla_statuses.present?
          @project.response_sla.destroy if @project.response_sla.present?
          @project.sla_working_day.destroy if @project.sla_working_day.present?
        end
        flash[:notice] = l(:notice_successful_update)
        redirect_to settings_project_path(@project, :tab => 'modules')
      end

      def show
        # try to redirect to the requested menu item
        if params[:jump] && redirect_to_project_menu_item(@project, params[:jump])
          return
        end
        #@users_by_role = @project.users_by_role
        @subprojects = @project.children.visible.all
        
        @news = @project.news.limit(5).includes(:author, :project).reorder("#{News.table_name}.created_on DESC").all
        @trackers = @project.rolled_up_trackers
        cond = @project.project_condition(Setting.display_subprojects_issues?)
        @open_issues_by_tracker = Issue.visible.open.where(cond).group(:tracker).count
        @total_issues_by_tracker = Issue.visible.where(cond).group(:tracker).count

        if User.current.allowed_to?(:view_time_entries, @project)
          @total_hours = TimeEntry.visible.where(cond).sum(:hours).to_f
        end

        @key = User.current.rss_key

        respond_to do |format|
          format.html
          format.api
        end
      end

       def update
        @project.safe_attributes = params[:project]
        if validate_parent_id && @project.save
          @project.set_allowed_parent!(params[:project]['parent_id']) if params[:project].has_key?('parent_id')
          @project.dept_code = params[:project]["dept_code"]
          @project.save
          respond_to do |format|
            format.html {
              flash[:notice] = l(:notice_successful_update)
              redirect_to settings_project_path(@project)
            }
            format.api  { render_api_ok }
          end
        else
          respond_to do |format|
            format.html {
              settings
              render :action => 'settings'
            }
            format.api  { render_validation_errors(@project) }
          end
        end
        @project
      end

      def settings
        @offset, @limit = api_offset_and_limit
        @limit = per_page_option
        
        # if params[:tab] == 'members'
          @member_count1 = @project.member_principals.count
          @member_pages1 = Redmine::Pagination::Paginator.new @member_count1, @limit, params['page']
          @offset ||= @member_pages1.offset
        # end
         @members_list =  @project.member_principals.includes(:member_roles).order("#{Member.table_name}.id").limit(@limit).offset(@offset).all
        #p members_list_query = "select m.id,m.project_id,m.user_id from members m
#        #join users u on m.user_id=u.id
#        #join member_roles mr on mr.member_id=m.id
#        #join roles r on r.id=mr.role_id
#        #where u.status=1  and m.project_id= #{@project.id} group by u.id " 
#
        #@members_list = Member.find_by_sql(members_list_query).limit(@limit).offset(@offset).all

        @category_names=[]
        if params[:category].present? && !params[:search_tags].present?
          category = ProjectCategory.find(params[:category])
          @tags = TicketTag.joins(:category).where( :project_categories => {:id => params[:category], :project_id => @project.id,:need_approval => true }).order("cat_name asc").order("name asc")
          @category_names = [category.id, category.cat_name]
        elsif params[:search_tags].present?
          name = ProjectCategory.where(:id => params[:category])
          @category_names = name.map {|e| [e.id, e.cat_name] }.flatten
          @tags = TicketTag.joins(:category).where( :project_categories => {:project_id => @project.id,:need_approval => true }, :ticket_tags => {:id => params[:search_tags].split(',')}).order("cat_name asc").order("name asc")
          @tag_ids = @tags.map(&:id)
        else
          @tags = TicketTag.joins(:category).where( :project_categories => {:project_id => @project.id,:need_approval => true }).order("cat_name asc ,name asc")
        end
        @root = @tags.maximum(:root)
        #if params[:tab] == 'ticketing_approval_system'
        
        @tag_count = @tags.count
        @tag_pages = Redmine::Pagination::Paginator.new @tag_count, @limit, params['page']
        @offset = @tag_pages.offset
        @team = @project.get_team_members
        #else
        #end
        @tag_list = @tags.limit(@limit).offset(@offset)
        @issue_custom_fields = IssueCustomField.sorted.all
        @issue_category ||= IssueCategory.new
      #end
        @member ||= @project.members.new
        @trackers = Tracker.sorted.all
        @wiki ||= @project.wiki
        respond_to do |format|
          format.js
          format.html
        end
      end

      def with_format(format, &block)
        old_formats = formats
        self.formats = [format]
        block.call
        self.formats = old_formats
        nil
      end

      def datatable_values
        @project = Project.find(params[:project_id])
        if params[:page].present?
        else
          params[:page]=1
        end
        @offset, @limit = api_offset_and_limit
        @limit = per_page_option
        @members_data = []
        @member_count1 = Member.where(:project_id=>@project.id).count
        @member_pages1 = Redmine::Pagination::Paginator.new @member_count1, params[:length].to_i, params['page']
        offsets=0
        page_limit = params[:length]
        search = params[:search]
        page_number  = params[:page].to_i 
        if page_number.to_i > 0
          offsets = (page_number-1)*params[:length].to_i
        end 
        
        order_name=''
        if params[:order].present?
          order_values = params[:order].split(',')
          if order_values.first.to_i==0
            order_name=" order by u.firstname #{order_values.last}"
          elsif order_values.first.to_i==1
            order_name=" order by r.name #{order_values.last}"
          end
        end

        @members_list =  @project.member_principals.includes(:member_roles).order("#{Member.table_name}.id").limit(page_limit).offset(offsets)
        query_param = "%#{params[:search]}%"
        #p members_list_query = "select m.id,m.project_id,m.user_id,u.status from members m
        #join users u on m.user_id=u.id
        #join member_roles mr on mr.member_id=m.id
        #join roles r on r.id=mr.role_id
        #where u.firstname like '#{query_param}' OR u.lastname like '#{query_param}' OR r.name like '#{query_param}' and m.project_id= #{@project.id} group by u.id #{order_name}  limit #{page_limit}  offset #{offsets}" 
        members_list_query = "select m.id,m.project_id,m.user_id,u.status from members m
        join users u on m.user_id =u.id and u.status=1
        join member_roles mr on mr.member_id=m.id
        join roles r on r.id=mr.role_id
         where (u.firstname like '#{query_param}' OR u.lastname like '#{query_param}'
        OR r.name like '#{query_param}') and m.project_id= #{@project.id}
        group by u.id  #{order_name}  limit #{page_limit}  offset #{offsets}  "
        @members_list = Member.find_by_sql(members_list_query)
        @roles = Role.find_all_givable
        @members = @members_list 
        if params[:search].present?
          search_limit = @members_list.count
          @member_pages1 = Redmine::Pagination::Paginator.new search_limit,search_limit, params['page']
        end
        with_format :html do
          @html_content = render_to_string(partial: 'projects/settings/members_body', :locals => { :members => @members })
          @pagination_content = render_to_string(partial: 'projects/settings/members_pagination', :locals => { :member_pages => @member_pages1, :member_count1 => @member_count1})
        end
        respond_to do |format|
          format.html {  render render_to_string(partial: 'projects/settings/members_body', :locals => { :members => @members })  } #, flash[:success] = "holder updated")
          format.js {render :json => { :attachmentPartial => @html_content,:paginationPartial => @pagination_content }}
        end
      end

    end
  end
end
