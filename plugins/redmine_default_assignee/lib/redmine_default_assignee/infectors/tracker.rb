module RedmineDefaultAssignee
  module Infectors
    module Tracker
      module ClassMethods; end

      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable

          has_one :default_assignee_setup, :foreign_key => 'tracker_id'
        end
      end

    end
  end
end