class Issue < ActiveRecord::Base

  has_one :ticket_tag, :through => :issue_ticket_tag
  has_one :inia_project, :through => :issue_ticket_tag
  has_one :issue_ticket_tag
  has_one :request_remainder
  has_many :issue_approval_details
  has_many :ticket_approval_flows
  has_one :user_rating
  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'

end