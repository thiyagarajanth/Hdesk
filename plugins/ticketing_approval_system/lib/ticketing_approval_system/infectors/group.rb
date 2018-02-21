module TicketingApprovalSystem
  module Infectors
    module Group
      module ClassMethods; end

      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
         attr_accessor :add_user
         has_one :sync_entity, :foreign_key => "entity_id"
        end
      end

    end
  end
end