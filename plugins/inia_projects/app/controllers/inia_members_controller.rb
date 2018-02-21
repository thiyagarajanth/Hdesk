class String
  def to_nil
    present? ? self : nil
  end
end
class IniaMembersController < ApplicationController
  unloadable
  skip_before_filter :authorize

  def index
    p '------resrtet-----------'
    p request.remote_ip
   if params[:data]=='i'
     params.delete(:id)
   end
    @inia_projects = []
    project_ids = []
    users = []
   @roles = []
   @dept=[]; Project.all.collect{|rec|  @dept << rec if rec.approval_roles.present?}
    IniaMember.where(user_id: User.current.id).each { |member|
      member.inia_roles.each { |role|
        project_ids <<  member.project_id if role.permissions.include?(:manage_members)
      }
    }
    members = []
    IniaMember.where(:user_id => User.current.id).each do|member|
      member.inia_roles.collect{|role|members << member if role.permissions.include?('manage_members')}
    end
    if User.current.admin?
      @projects = IniaProject.where(:status => 1).order('name asc')
    else
      @projects = IniaProject.where(:id => project_ids, :status => 1).order('name asc')
    end
    # project_ids = members.uniq.map(&:project_id)
#==========================================================
    if params[:dept_id].present?
      @levels = ApprovalRole.where(:project_id=>params[:dept_id])
      if params[:list].present?
        @project_list = []
        @projects = @projects.each do |project|
          data = []

          @levels.each do |rec|
            user_id = ApprovalRoleUser.find_by_sql("select a.user_id,u.firstname from approval_role_users as a,approval_roles as ar, users u where a.inia_project_id=#{project.id} and ar.level=#{rec.level} and a.approval_role_id = ar.id and a.user_id=u.id and u.status=1 and a.project_id=#{params[:dept_id]}").map{|p| [p.user_id, p.firstname]}.last
          #user_id = IniaMember.find_by_sql("select m.user_id,u.firstname from inia_members as m, users as u, approval_roles_inia_members as arim, approval_roles as ar where m.project_id=#{project.id} and m.id=arim.inia_member_id and ar.project_id=#{params[:dept_id]} and ar.level=#{rec.level} and m.project_id=#{project.id} and arim.approval_role_id=ar.id and m.user_id=u.id").map{|p| [p.user_id, p.firstname]}.last

          user_id = user_id.present? ? user_id : ['','']
            data << [user_id,rec.id,  rec.level, rec.can_restrict, rec.project_id]
          end
          @project_list << [project.name,project.id,data]
          # @levels.each do |rec|
          #   project.inia_members.each{|a|  data = [a.user.id,a.user.firstname]  if a.approval_roles.where(:project_id => params[:dept_id]).map(&:level).include?(rec.level)}
          #   col << data
          # end
          # p col
        end
        params.merge!(:tab =>'Config')
      else
        levels = @levels.map(&:level)
        @projects.each do |project|
          roles = []
          project.inia_members.collect do |x|
            roles << x.approval_roles.where(:project_id => params[:dept_id]).map(&:level) if x.user.present? && x.user.active?
          end
          @inia_projects << [project.id,project.name,project.description] if !(levels-roles.flatten).empty?
        end
        @inia_projects
        params.merge!(:tab =>'lacking_workflow')
      end
    elsif params[:id].present? && params[:id] == 'group_users' && params[:type].present?
      projects = Project.where('name like ?',"%#{params[:term]}%").collect{|rec| {id:rec.id, text:rec.name} if rec.approval_roles.present?}
    elsif params[:id].present? && params[:id] == 'group_users' && params[:state].present?
#      IniaProject.find(params[:project_id]).inia_members.collect{|rec| users << {id:rec.user.id, text:rec.user.name} if rec.user.present? }
      users = User.find_by_sql("select u.id,u.firstname, u.lastname from users as u , inia_members im, inia_projects ip where u.id=im.user_id and u.status=1 and ip.id=#{params[:project_id]} and im.project_id=ip.id and (u.firstname like '%#{params[:term]}%' or u.lastname like '%#{params[:term]}%')  order by u.firstname").collect{|rec| {id:rec.id, text:rec.firstname+' '+rec.lastname} }
    elsif params[:id].present? && params[:id] == 'group_users'
      group = Group.find_by_lastname('Everyone')
      if group.present?
        users = group.users.active.where('firstname like ? or lastname like ?', "%#{params[:term]}%","%#{params[:term]}%").collect{|rec| {id:rec.id, text:rec.name} }
      else
        users = []
      end
    elsif params[:id].present?
      @inia_project = IniaProject.find(params[:id])
      @roles = []
      ApprovalRole.all.each do |role|
        @roles << role
      end
    end
    params.merge!(:tab =>'lacking_workflow') if params[:data] == 'w'

   #===================================================================================

   if params[:id].present? && params[:id] == 'group_users'
     users =  users.sort_by { |k| k[:text] }
     res = params[:type].present? ? projects.compact : users
     render :json => {result: res }
   else
     render 'index'
   end
  end

  def create
    # users = params[:user_id]
    # if users.present?
    #   users.each_with_index do |d,i|
    #     if d.present?
    #       rec = ApprovalRoleUser.find_or_initialize_by_inia_project_id_and_approval_role_id(params[:inia_project_id].last, params[:role_id][i])
    #       rec.user_id = d
    #       rec.project_id = params[:project_ids][i]
    #       rec.save
    #     end
    #   end
    # end

    params[:role_id].each_with_index do |role_id , i|
      role = ApprovalRoleUser.find_or_initialize_by_inia_project_id_and_approval_role_id(params[:inia_project_id].last,role_id)
      old_user = role.user_id
      if role.present? && !params[:user_id][i].empty?
        role.user_id = params[:user_id][i]
        role.project_id = params[:project_ids][i]
        role.save
      end

      dashboard_helper = Object.new.extend(DashboardHelper)
      status = dashboard_helper.get_approval_statuses
      old_user_issues = Issue.where(:status_id =>status, :assigned_to_id => old_user)
      old_user_issues.each do |issue|
        next if issue.inia_project.present? && !params[:inia_project_id].map(&:to_i).include?(issue.inia_project.id) #(issue.inia_project.id != params[:inia_project_id].to_i)
        next  if role.user_id == issue.assigned_to_id
        next  if !params[:project_ids].include?(issue.project_id.to_s)
        issue.assigned_to_id = role.user_id
        issue.init_journal(User.current, "Assignee changed from #{User.find(old_user).name} to #{User.find(role.user_id).name}")
        tp = TicketApproval.find_by_approval_role_id_and_ticket_tag_id(role.approval_role_id, issue.ticket_tag.id)
        tpap = TicketApprovalFlow.find_by_issue_id(issue.id).last.ticket_approval.approval_role_id rescue nil
        issue.save if tpap.present?
        TicketApprovalFlow.find_by_issue_id_and_ticket_approval_id(issue.id, tp.id).update_attributes(:status => 'Approver changed')
        tpf =  TicketApprovalFlow.new(:issue_id => issue.id, :ticket_approval_id => tp.id, :user_id => issue.assigned_to_id, :status => 'pending', :notes => "Approver changed" )
        tpf.save
      end
      role.delete if params[:user_id][i].empty?
    end
    render :json => {'ok'=>true}
  end

  def members
    @inia_project = IniaProject.find(params[:id])
    @roles = []
    ApprovalRole.all.each do |role|
      @roles << role
    end
  end

  def edit
  end

  def update
    # params[:user_ids].each_with_index do |user_id , i|
    #   if user_id.present?
    #     member =  IniaMember.find_by_user_id_and_project_id(user_id, params[:inia_project_id])
    #     if member.present?
    #       role = ApprovalRoleUser.find_or_initialize_by_inia_project_id_and_approval_role_id(params[:inia_project_id],params[:role_ids][i])
    #       role.user_id = user_id
    #       role.project_id = params[:project_ids][i]
    #       role.save
    #     end
    #   end
    # end

    params[:role_ids].each_with_index do |role_id , i|
      role = ApprovalRoleUser.find_or_initialize_by_inia_project_id_and_approval_role_id(params[:inia_project_id],role_id)
      old_user = role.user_id
      if role.present? && !params[:user_ids][i].empty?
        IniaMember.find_by_user_id_and_project_id(params[:user_ids][i], params[:inia_project_id])
        role.user_id = params[:user_ids][i]
        role.project_id = params[:project_ids][i]
        role.save
      end

      dashboard_helper = Object.new.extend(DashboardHelper)
      status = dashboard_helper.get_approval_statuses
      old_user_issues = Issue.where(:status_id =>status, :assigned_to_id => old_user)
      old_user_issues.each do |issue|
        next if issue.inia_project.present? && (issue.inia_project.id != params[:inia_project_id].to_i)
        next  if role.user_id == issue.assigned_to_id
        issue.assigned_to_id = role.user_id
        issue.init_journal(User.current, "Assignee changed from #{User.find(old_user).name} to #{User.find(role.user_id).name}")
        issue.save
        tp = TicketApproval.find_by_approval_role_id_and_ticket_tag_id(role.approval_role_id, issue.ticket_tag.id)
        TicketApprovalFlow.find_by_issue_id_and_ticket_approval_id(issue.id, tp.id).update_attributes(:status => 'Approver changed')
        tpf =  TicketApprovalFlow.new(:issue_id => issue.id, :ticket_approval_id => tp.id, :user_id => issue.assigned_to_id, :status => 'pending', :notes => "Approver changed" )
        tpf.save
      end
      role.delete if params[:user_ids][i].empty?
    end


    respond_to do |format|
      flash[:notice] = 'Approval Roles Successfully  Updated.'
      format.html { redirect_to_settings_in_projects }
      format.js
      format.api {
        if saved
          render_api_head :ok
        else
          render_validation_errors(@member)
        end
      }
    end
  end


  # def group_users
  #   group = Group.find_by_lastname('Everyone')
  #   if group.present?
  #     conditions = ['name like ?', "%#{params[:term]}%"]
  #     users = group.users.where(conditions).collect{|rec| {id:rec.id, text:rec.name} }
  #   else
  #     users = []
  #   end
  #   render :json => {result: users }
  # end

end