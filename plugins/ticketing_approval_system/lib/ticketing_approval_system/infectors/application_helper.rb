module TicketingApprovalSystem
  module Infectors
    module ApplicationHelper
      module ClassMethods;
      end

      module InstanceMethods;
      end

      def self.included(receiver)
        receiver.extend         ClassMethods
        receiver.send :include, InstanceMethods
        receiver.class_eval do
          unloadable
          # alias_method_chain :project_settings_tabs, :ticketing_approval_system

          def issue_principals_check_box_tags(access_users,name, principals)
            s = ''
            principals.each do |principal|

              s << "<label>#{ check_box_tag name, principal.id, access_users.include?(principal.id) ? true : false , :id => nil } #{h principal}</label>\n"
            end
            s.html_safe
          end
        end
      end
    end
  end
end