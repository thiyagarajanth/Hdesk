class TicketTag < ActiveRecord::Base
  unloadable
  # has_and_belongs_to_many :isses
  # has_many :approval_definitions, :dependent => :destroy
  has_many :ticket_approvals, :dependent => :destroy
  belongs_to :tracker
  belongs_to :project
  belongs_to :project_category, :class_name => "ProjectCategory", :foreign_key => :category_id
  belongs_to :category, :class_name => "ProjectCategory", :foreign_key => :category_id
  belongs_to :parent, class_name: "TicketTag", foreign_key: 'parent_id'
  has_one :child, :class_name => "TicketTag", foreign_key: 'parent_id'
  has_many :issues, :through => :issue_ticket_tags
  has_many :issue_ticket_tags
  has_many :request_remainders

  validates :validity, :numericality => { :greater_than_or_equal_to => 0 }
  validates :name, uniqueness: {scope: [:project_id, :category_id,:parent_id, :root]}
end
