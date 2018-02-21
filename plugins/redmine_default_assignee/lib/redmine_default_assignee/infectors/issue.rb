

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
          before_validation :reset_assignee

          def assign_default_assignee
            issue_changes = self.changes
            project_id = self.project_id if self.project_id.present?
            tracker_id = self.tracker_id if self.tracker_id.present?
            default_assignee = DefaultAssigneeSetup.where(:project_id=>project_id,:tracker_id=>tracker_id) if project_id.present? && tracker_id.present?
            project = Project.find(project_id)
            if project.enabled_modules.map(&:name).include?('status_assignee')
              status = self.status_id
              rec = DefaultAssigneeSetup.find_by_project_id_and_tracker_id_and_status_id(project_id,tracker_id,status)
              if issue_changes.has_key?("status_id")
                if rec.present?
                  if rec.assignee == "author"
                    self.assigned_to_id = self.author_id
                  elsif rec.assignee == "default_assignee"
                    self.assigned_to_id = rec.default_assignee_to
                  end
                end
              end
            else
              if !self.assigned_to_id.present?
                self.assigned_to_id = default_assignee.last.default_assignee_to if default_assignee.present? && default_assignee.last.default_assignee_to.present?
              end
            end
          end

          #added below method for purpose of during assigned status assignee should not be default assignee.
          def reset_assignee
            assigned_status = IssueStatus.find_by_name('assigned')
            status = self.status_id
            if status == assigned_status.id
              assignee = self.assigned_to_id
              check_assignee = Group.find(assignee) rescue nil
              if check_assignee.present?
               self.assigned_to_id = ""
              end
            end
          end
        end
      end

      module InstanceMethods

      end
      
    end
  end
end