module SlaReports
  module Infectors
    module Issue
      module ClassMethods; end
      module InstanceMethods
        def remarks
          @remarks = self.issue_detail.remarks rescue nil
        end
        def request_status
          if self.due_date.nil?
            @request_status   = nil
          elsif self.due_date >= Date.today
            @request_status  = 'Active' 
          elsif self.due_date < Date.today
            @request_status   = 'Expired'          
          end
        end
      end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable

          has_one :issue_detail


        end
      end
    end
  end
end