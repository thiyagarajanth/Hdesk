class IniaRole < ActiveRecord::Base
  has_many :inia_member_roles, :dependent => :destroy, :foreign_key => "role_id"
  has_many :inia_members, :through => :inia_member_roles, :foreign_key => "role_id"

  class PermissionsAttributeCoder
    def self.load(str)
      str.to_s.scan(/:([a-z0-9_]+)/).flatten.map(&:to_sym)
    end

    def self.dump(value)
      YAML.dump(value)
    end
  end

  serialize :permissions, ::Role::PermissionsAttributeCoder
end