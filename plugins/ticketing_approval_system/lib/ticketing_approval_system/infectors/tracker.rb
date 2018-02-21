module TicketingApprovalSystem
  module Infectors
    module Tracker
      CORE_FIELDS_UNDISABLABLE = %w(project_id tracker_id subject description priority_id is_private).freeze
      # Fields that can be disabled
      # Other (future) fields should be appended, not inserted!
      CORE_FIELDS = %w(assigned_to_id category_id fixed_version_id parent_issue_id start_date due_date estimated_hours done_ratio project_ids approval_workflow).freeze
      CORE_FIELDS1 = %w(assigned_to_id category_id fixed_version_id parent_issue_id start_date due_date estimated_hours done_ratio project_ids approval_workflow).freeze
      CORE_FIELDS_ALL = (CORE_FIELDS_UNDISABLABLE + CORE_FIELDS1).freeze
      module ClassMethods;  end

      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          has_many :approval_roles
          def disabled_core_fields
            i = -1
            @disabled_core_fields ||= CORE_FIELDS1.select { i += 1; (fields_bits || 0) & (2 ** i) != 0}
          end

          def core_fields
            CORE_FIELDS1 - disabled_core_fields
          end

          def core_fields=(fields)
            raise ArgumentError.new("Tracker.core_fields takes an array") unless fields.is_a?(Array)

            bits = 0
            CORE_FIELDS1.each_with_index do |field, i|
              unless fields.include?(field)
                bits |= 2 ** i
              end
            end
            self.fields_bits = bits
            @disabled_core_fields = nil
            core_fields
          end



          # Returns the fields that are enabled for one tracker at least
          def self.core_fields(trackers)
            if trackers.present?
              trackers.uniq.map(&:core_fields).reduce(:|)
            else
              CORE_FIELDS1.dup
            end
          end


        end
      end

    end
  end
end