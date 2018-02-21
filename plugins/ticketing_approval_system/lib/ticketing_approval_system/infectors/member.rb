module TicketingApprovalSystem
  module Infectors
    module Member
      module ClassMethods; end

      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          after_destroy :remove_team_members

          def remove_team_members
            mem = TeamProfile.find_by_user_id_and_project_id(self.user_id, self.project_id)
            mem.destroy if mem.present?
          end
        end
      end
    end
  end
end