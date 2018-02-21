module ApplicationControllerPatch
  def self.included(base)
    base.class_eval do

      def find_issue
        # Issue.visible.find(...) can not be used to redirect user to the login form
        # if the issue actually exists but requires authentication
        @issue = Issue.find(params[:id])
        sql = "select issue_id from ticket_approval_flows where status='approved' and user_id=#{User.current.id}"
#         s = ApprovalRoleUser.where(:active_user => 'secondary_user', :secondary_user_id => @issue.assigned_to_id, :inia_project_id => @issue.inia_project.id).last

#         q = "select itt.issue_id from issue_ticket_tags itt
# join issues i on i.id=itt.issue_id
# join approval_role_users aru on aru.inia_project_id = itt.inia_project_id
# where aru.primary_user_id=#{s.primary_user_id} and aru.active_user='secondary_user'
# and i.assigned_to_id=aru.secondary_user_id" if s.present?
        if @issue.project.enabled_modules.map(&:name).include?('sla_reports')
          st = IssueDetail.find_by_sql(sql).map(&:issue_id).include?(@issue.id)
        else
          st = false
        end
        # d = s.present? ? (IssueTicketTag.find_by_sql(q).map(&:issue_id).include?(@issue.id)) : false
        if st && action_name =='show'
        else
          raise Unauthorized unless @issue.visible?
        end
        @project = @issue.project
      rescue ActiveRecord::RecordNotFound
        render_404
      end
    end
      #alias_method_chain :show, :plugin # This tells Redmine to allow me to extend show by letting me call it via "show_without_plugin" above.
      # I can outright override it by just calling it "def show", at which case the original controller's method will be overridden instead of extended.
  end
end