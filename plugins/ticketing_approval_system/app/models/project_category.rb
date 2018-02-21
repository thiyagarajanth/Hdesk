class ProjectCategory < ActiveRecord::Base
  unloadable
  # has_many :category_approval_configs
  # has_many :non_approval_tickets
  belongs_to :project
  has_many :ticket_tags, :foreign_key => :category_id
  has_many :issue_ticket_tags
  validates :cat_name, presence: true, :uniqueness => {:scope => :project_id,:allow_blank => true, case_sensitive: false}, format: { with: /^[a-zA-Z0-9\s]+$/, message: "only allows Alphanumeric" }

end
