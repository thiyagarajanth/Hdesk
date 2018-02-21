module SlaReports
  module Infectors
    module ProjectsHelper
      module ClassMethods; end

      module InstanceMethods

        def project_reports_tabs
          tabs = [
                       {:name => 'request_validity', :action => :manage_wiki, :partial => 'sla_reports/user_request_validity', :label => :label_request_validity},
                   ]
          if  permission_checker('sla_reports')
            tabs = [
                    {:name => 'sla', :action => :manage_wiki, :partial => 'sla_reports/sla', :label => :label_sla},
                    {:name => 'request_validity', :action => :manage_wiki, :partial => 'sla_reports/request_validity', :label => :label_request_validity},
            ]
            if (User.current.allowed_to?(:manage_members, @project) || User.current.admin?)
              tabs << {:name => 'user_rating', :action => :manage_wiki, :partial => 'sla_reports/user_rating', :label => :label_user_rating}
            end
          end
          tabs.select {|tab| User.current.allowed_to?(:sla_reports, @project)}
        end

        def permission_checker(permission)
          project_iden = Project.find_by_identifier(params[:project_id]).id rescue nil
          project_id =  Project.find(params[:project_id])
          access = []
          members = Member.where(user_id: User.current.id, :project_id => [project_id, project_iden])
          members.each { |member|
            member.roles.each { |role|
              access << role.permissions.include?(permission.to_sym)
            }
          } if members.present?
          User.current.admin? || access.include?(true)
        end
      end

      def self.included(receiver)
        receiver.extend         ClassMethods
        receiver.send :include, InstanceMethods
        receiver.class_eval do
          unloadable
        end
      end
    end
  end
end