class DefaultAssigneeSetup < ActiveRecord::Base
  unloadable
  #belongs_to :issue
  belongs_to :assigned_issue, :class_name => 'Issue', :foreign_key => 'default_assignee_to'
  validates_presence_of :tracker_id,:message => "Tracker is required."
  validates_presence_of :default_assignee_to,:message => "Assignee is required"
  validates_presence_of :project_id,:message => "Project is required"
  belongs_to :assigned_princepal, :class_name => 'Principal', :foreign_key => 'default_assignee_to'
  belongs_to :tracker
  belongs_to :status, :class_name => 'IssueStatus', :foreign_key => 'status_id'
  belongs_to :project

  def self.assignee_values
    assignee = [["no-change","nc"],["Author","author"],["Default Assignee","default_assignee"]]
  end
end
