class IssueTicketTag < ActiveRecord::Base
  unloadable
  belongs_to :issue
  belongs_to :ticket_tag
  belongs_to :inia_project
end
