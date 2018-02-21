module ProjectsControllerPatch
  def self.included(base)
    base.class_eval do
      menu_item :settings, :only => :settings
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

      def settings
        @offset, @limit = api_offset_and_limit
        @limit = per_page_option
        @member_count1 = @project.member_principals.count
        @member_pages1 = Redmine::Pagination::Paginator.new @member_count1, @limit, params['page']
        @offset ||= @member_pages1.offset
        @members_list =  @project.member_principals.includes(:member_roles).order("#{Member.table_name}.id").limit(@limit).offset(@offset).all
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
        @tag_count = @tags.count
        @tag_pages = Redmine::Pagination::Paginator.new @tag_count, @limit, params['page']
        @offset = @tag_pages.offset
        @tag_list = @tags.limit(@limit).offset(@offset)
        @issue_custom_fields = IssueCustomField.sorted.all
        @issue_category ||= IssueCategory.new
        @member ||= @project.members.new
        @trackers = Tracker.sorted.all
        @wiki ||= @project.wiki
        respond_to do |format|
          format.js
          format.html
        end
      end

    end
  end
end
