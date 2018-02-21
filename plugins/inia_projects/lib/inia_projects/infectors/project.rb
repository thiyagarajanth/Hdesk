module IniaProject
  module Infectors
    module Role
      module ClassMethods; end

      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          # has_many :inia_member_nanba_roles
          has_many :approval_role_inia_members, :dependent => :destroy
          has_many :inia_members, :through => :approval_role_inia_members
          has_many :users, :through => :approval_role_users
        end
      end

    end
  end
end