require 'redmine'

#RAILS_DEFAULT_LOGGER.info 'Starting Redmine SLA plugin'

require_dependency 'issues_controller_patch'
require_dependency 'projects_controller_patch'
IssuesController.send(:include, IssuesControllerPatch)
ProjectsController.send(:include, ProjectsControllerPatch)

Redmine::Plugin.register :redmine_issue_sla do
  name 'Redmine Issue SLA'
  author 'Ricardo Santos'
  description 'Show SLA information for support tickets'
  version '1.0.0'
  requires_redmine :version_or_higher => '2.2.0'

  project_module :redmine_issue_sla do
    # permission :view_issue_sla, {:issues => [:index, :show]}, :require => :member
    permission :manage_issue_sla, {:issue_slas => [:update]}, :require => :member
    # permission :be_project_manager, {}, :require => :member
    permission :response_sla,  {:issue_slas => [:response_sla]}, :require => :member

  end
end

RedmineApp::Application.config.after_initialize do
  require_dependency 'redmine_issue_sla/infectors'
end

# hooks
require_dependency 'redmine_issue_sla/hooks'

# Rails.configuration.to_prepare do
#   require 'rufus/scheduler'
#   scheduler = Rufus::Scheduler.new
#   sla_time_helper = Object.new.extend(SlaTimeHelper)

#   scheduler.cron '00 23 * * *' do
#     sla_time_helper.update_time_entry_end_of_day
#     p  "it's 11am! good night!"
#   end

# end

Rails.configuration.to_prepare do
  require 'rufus/scheduler'

  sla_time_helper = Object.new.extend(SlaTimeHelper)

  if defined?(PhusionPassenger)
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
      if forked
        scheduler = Rufus::Scheduler.new
        scheduler.cron "00 13 * * *" do
          Rails.logger.info "Auto Close Job started"
          sla_time_helper.auto_closing
          Rails.logger.info "Auto Close Job Ended"
        end
      end
    end
  end
end