RedmineApp::Application.config.after_initialize do
  require_dependency 'redmine_default_assignee/infectors'
  #config.session_store :active_record_store
  # RedmineApp::Application.config.session_store :active_record_store
end

Rails.configuration.to_prepare do
  require_dependency 'redmine_default_assignee/projects_helper_patch'
  require_dependency 'default_assignee_setup_helper'
  require_dependency 'redmine_default_assignee/application_helper_patch'
end

ProjectsHelper.send(:include, RedmineDefaultAssignee::ProjectsHelperPatch)
ApplicationHelper.send(:include, RedmineDefaultAssignee::ApplicationHelperPatch)

Redmine::Plugin.register :redmine_default_assignee do
  name 'Redmine Default Assignee plugin'
  author 'OFS'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://ofmc.objectfrontier.com/'
  author_url 'http://ofmc.objectfrontier.com/'

  project_module :default_assign do
    permission :default_assignee_setup, :default_assignee_setup => :index
    permission :result,  {:default_assignee_setup => [:result]},:public => true
  end
  project_module :status_assignee do
    permission :status_assignee, { :controller => 'DefaultAssigneeSetupController' }, :require => :member
  end
 # menu :project_menu, :set_default_assignee, { :controller => 'default_assignee_setup', :action => 'index' }, :caption => :lable_default_assignee, :before => :settings, :param => :project_id

end
