module IniaProject
  module Infectors
    module User
      module ClassMethods; end

      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          has_many :inia_member_roles, :dependent => :destroy, :foreign_key => "user_id"
          has_many :approval_role_users
        end
      end

    end
  end
end