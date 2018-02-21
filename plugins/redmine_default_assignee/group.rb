module RedmineDefaultAssignee
  module Infectors
    module Issue
      module ClassMethods
      end
      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          #validates_numericality_of :external_id,:presence => true

          #validates_length_of :notes, :maximum => 255, :allow_nil => true
          has_one :default_assignee_setup, :class_name => 'DefaultAssigneeSetup', :foreign_key => 'project_id'
          before_save :assign_default_assignee
          def assign_default_assignee
            project_id = self.project_id if self.project_id.present?
           tracker_id = self.tracker_id if self.tracker_id.present?
            default_assignee = DefaultAssigneeSetup.where(:project_id=>project_id,:tracker_id=>tracker_id) if project_id.present? && tracker_id.present?
            if !self.assigned_to_id.present?
            self.assigned_to_id = default_assignee.last.default_assignee_to if default_assignee.present?
            end
            end
        end
      end

      module InstanceMethods

      end
      
    end
  end
end