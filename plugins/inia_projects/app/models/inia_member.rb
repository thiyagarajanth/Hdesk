class IniaMember < ActiveRecord::Base
  # attr_accessible :title, :body
  belongs_to :inia_project, :foreign_key => "project_id"
  has_many :inia_roles
  has_many :roles
  belongs_to :user
  has_many :inia_roles, :through => :inia_member_roles, :uniq => true, :foreign_key => "member_id"
  has_many :approval_roles, :through => :approval_role_inia_members, :uniq => true, :foreign_key => "inia_member_id"
  has_many :inia_member_roles, :dependent => :destroy, :foreign_key => "member_id"
  # has_many :inia_member_nanba_roles, :dependent => :destroy, :foreign_key => "member_id"
  has_and_belongs_to_many :approval_roles
  has_many :approval_role_inia_members, :dependent => :destroy, :foreign_key => "inia_member_id"

  attr_accessor :a3,:a4
end
