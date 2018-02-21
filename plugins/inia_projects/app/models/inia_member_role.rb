class IniaMemberRole < ActiveRecord::Base
  belongs_to :inia_member
  belongs_to :inia_role, :foreign_key => "role_id"
  # belongs_to :role

end
