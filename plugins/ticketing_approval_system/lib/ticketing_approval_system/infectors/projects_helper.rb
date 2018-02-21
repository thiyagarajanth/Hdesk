module TicketingApprovalSystem
  module Infectors
    module ProjectsHelper
      module ClassMethods; end

      module InstanceMethods
        def project_settings_tabs_with_ticketing_approval_system
          tabs = project_settings_tabs_without_ticketing_approval_system
          return tabs unless @project.module_enabled?('ticketing_approval_system')
          if User.current.allowed_to?(:manage_ticketing_approval, @project)
            tabs << {:name => 'ticketing_approval_system', :action  => :manage_ticketing_approval, :partial => 'projects/settings/ticketing_approval_system', :label => :label_ticketing_approval_system}
            tabs << {:name => 'team_members', :action  => :manage_ticketing, :partial => 'projects/settings/manage_team_members', :label => :label_manage_team_members}
          end
          tabs
        end

      end

      def self.included(receiver)
        receiver.extend         ClassMethods
        receiver.send :include, InstanceMethods
        receiver.class_eval do
          unloadable
          alias_method_chain :project_settings_tabs, :ticketing_approval_system
        end
      end
    end
  end
end