class IssueTicketTag < ActiveRecord::Base
  unloadable
  belongs_to :issue
  belongs_to :ticket_tag
  belongs_to :inia_project
  belongs_to :project_category, :foreign_key => 'category_id', :class_name => 'ProjectCategory'
end
