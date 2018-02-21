class ApprovalRole < ActiveRecord::Base
  unloadable
  has_many :ticket_approvals
  belongs_to :project
  belongs_to :tracker
  has_and_belongs_to_many :inia_members
  has_and_belongs_to_many :users
  has_one :approval_role_user
  has_one :approval_role_inia_member


  has_one :approver_sla

  # has_many :delegation_audits


  #has_many :issue_approval_details

  validates :name, presence: true, :uniqueness => {:scope => :project_id}
  validates :level, presence: true, numericality: { only_integer: true }, :uniqueness => {:scope => :project_id}


  def self.set_assignee_value(issue)
    if issue.project.enabled_modules.map(&:name).include?('default_assign')
      default_assignee =  DefaultAssigneeSetup.find_by_project_id_and_tracker_id(issue.project_id, issue.tracker_id)
      default_assignee = default_assignee.present? ? default_assignee : DefaultAssigneeSetup.new
      assigned_to_id = default_assignee.default_assignee_to
    else
      assigned_to_id = nil
    end
    assigned_to_id
  end

end
