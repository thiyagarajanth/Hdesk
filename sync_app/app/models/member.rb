class Member < ActiveRecord::Base
  # establish_connection "sync_prod"
  belongs_to :project

  has_many :member_roles
end