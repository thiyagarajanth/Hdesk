module RedmineIssueSla
  module Infectors
    module Issue
      module ClassMethods; end
  
      module InstanceMethods
        attr_accessor :attributes_before_change

        def priority_issue_sla
           tracker.issue_slas.where(:project_id => project_id).first
        end

      end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          cattr_accessor :skip_callbacks

          has_many :sla_times
          has_one :response_time, :class_name => 'ResponseTime', :foreign_key => 'issue_id'
          belongs_to :priority_sla,:class_name => 'IssueSla', :foreign_key => 'priority_sla_id'
          after_create :updated_estimated_hours
          # after_update :send_notification_for_update

          def updated_estimated_hours
            if self.project.enabled_modules.map(&:name).include?('redmine_issue_sla')
              hours = IssueSla.where(:project_id => self.project_id, :tracker_id =>self.tracker.id,:priority_id => self.priority.id).last
              # hours = self.project.issue_slas.where(:tracker_id =>self.tracker.id).where(:priority_id => self.priority.id).last
              self.update_attributes(:estimated_hours => hours.allowed_delay, :priority_sla_id => hours.id ) if hours.present?
            end
          end
        # Sending Notification while updation
          def send_notification_for_update
            if Setting.notified_events.include?('issue_updated')
              Mailer.deliver_issue_add(self)
            end
          end


        end
      end
    end
  end
end