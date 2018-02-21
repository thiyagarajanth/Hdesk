module RedmineDefaultAssignee
 module ProjectsHelperPatch
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)
        base.class_eval do
            unloadable
            alias_method_chain :project_settings_tabs, :default_assignee
        end
      end

      module ClassMethods
      end

      module InstanceMethods
        def project_settings_tabs_with_default_assignee
          tabs = project_settings_tabs_without_default_assignee
          return tabs unless @project.module_enabled?('default_assign')
          @project_trackers = @project.trackers
          @status = @project_trackers[0].issue_statuses if @project_trackers.present?
          @project_tracker_id = @project_trackers[0].id if @project_trackers.present?
          if User.current.allowed_to?(:default_assignee_setup, @project) || User.current.admin?
            @default_assignees = DefaultAssigneeSetup.where(:project_id=>@project.id).uniq_by{|u| u.default_assignee_to and u.tracker_id}
            tabs << {:name => 'default_assignee',:action => :index, :partial => 'default_assignee_setup/index', :label => :lable_default_assignee}
          end
          tabs
        end
      end
 end
  end


