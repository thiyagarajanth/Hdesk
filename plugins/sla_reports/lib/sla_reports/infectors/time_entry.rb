module SlaReports
  module Infectors
    module TimeEntry
      module ClassMethods; end
      module InstanceMethods;  end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable

          before_save :check_sla_met_or_not

          def check_sla_met_or_not
            entry = self.class.where(:issue_id => self.issue_id).group('issue_id').sum('hours').values[0]
            detail = IssueDetail.find_or_initialize_by_issue_id(self.issue_id)
            if self.id.present?
              t_hours = (entry - self.class.find(self.id).hours) + self.hours
            else
              t_hours = entry.to_f + self.hours.to_f
            end
            sla_hours = self.issue.estimated_hours.to_f
            status = sla_hours >= t_hours ? true : false
            detail.sla_duration = sla_hours
            detail.resolution_time = t_hours
            detail.is_met_sla=status
            detail.save
            # raise
            if status && self.issue.status.name == 'Resolved'
              return true
            elsif !status && self.issue.status.name == 'Resolved' && !detail.remarks.present?
              self.errors.add(:hours, "exceeding SLA time limit for this issue, So please give a reason for not met SLA.")
              return false
            end

          end
        end
      end
    end
  end
end