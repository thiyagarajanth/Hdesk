class MemberRole < ActiveRecord::Base
  # establish_connection "sync_prod"
  belongs_to :member
  belongs_to :role
end