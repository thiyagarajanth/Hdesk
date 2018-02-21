module IniaMembersHelper
  def approval_user(project_id,dept_id, level)
    project = IniaProject.find(project_id)
    members = project.approval_role_users.where(:inia_project_id => project.id)
    roles = []
    members.each do |member|
        if member.approval_role.present? && member.approval_role.level == level && member.approval_role.project_id == dept_id
          roles << member.user_id
        end
    end
    if roles.flatten.present?
      return roles[0]
    else
      return nil
    end
  end

  def migrate_app_role_member
    ApprovalRoleIniaMember.all.each do |member|
      if member.inia_member.present?
        role = ApprovalRoleUser.find_or_initialize_by_inia_project_id_and_approval_role_id(member.inia_member.project_id,member.approval_role_id)
        role.user_id = member.inia_member.user_id
        role.project_id = member.approval_role.project_id
        role.save
      end
    end

  end
  
  def check_active_approver(id)
    if id.present?
      user = User.find(id)
      user.active? ? user.name : ''
    else
      ''
    end
  end
  # def approval_user(project_id,dept_id, level)
  #   project = IniaProject.find(project_id)
  #   members = project.inia_members
  #   roles = []
  #   members.each do |member|
  #     mem = member.approval_roles.where(:project_id => dept_id, :level => level)
  #     roles << member.user_id if mem.count > 0
  #   end
  #   if roles.flatten.present?
  #     return roles[0]
  #   else
  #     return nil
  #   end
  # end
end
