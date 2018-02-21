require_dependency 'application_helper'






require_dependency 'application_helper'

module TicketingApprovalSystem


  module ApplicationHelperPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable
        # alias_method_chain :link_to_issue, :custom_show
      end
    end

    module InstanceMethods
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



