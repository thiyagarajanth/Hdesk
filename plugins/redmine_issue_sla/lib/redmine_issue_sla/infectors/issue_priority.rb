module RedmineIssueSla
  module Infectors
    module IssuePriority
      module ClassMethods; end
  
      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          
          has_many :issue_slas
          has_one :approver_sla
        end
      end
      
    end
  end
end