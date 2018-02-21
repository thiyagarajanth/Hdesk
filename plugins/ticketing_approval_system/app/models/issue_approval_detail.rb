class IssueApprovalDetail < ActiveRecord::Base
  unloadable
  belongs_to :ticket_approval
  belongs_to :issue

  belongs_to :user
  # belongs_to :parent, class_name: "IssueApprovalDetail", foreign_key: 'parent_id'
  # has_one :child, :class_name => "IssueApprovalDetail", foreign_key: 'parent_id'

end
