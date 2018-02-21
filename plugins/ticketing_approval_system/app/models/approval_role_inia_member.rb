class ApprovalRoleIniaMember < ActiveRecord::Base
	self.table_name = 'approval_roles_inia_members'
  belongs_to :inia_member
  belongs_to :role
  belongs_to :approval_role
end