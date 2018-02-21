
require 'redmine'
require 'open-uri'

# hooks
Rails.configuration.to_prepare do

  require_dependency 'issues_controller_patch'
  require_dependency 'groups_controller_patch'
  require_dependency 'projects_controller_patch'
  require_dependency 'context_menus_controller_patch'

  require_dependency 'application_controller_patch'

end


ApplicationController.send(:include, ApplicationControllerPatch)
IssuesController.send(:include, IssuesControllerPatch)
GroupsController.send(:include, GroupsControllerPatch)
ProjectsController.send(:include, ProjectsControllerPatch)
ContextMenusController.send(:include, ContextMenusControllerPatch)


Redmine::Plugin.register :ticketing_approval_system do
  name 'Ticketing Approval System'
  author 'OFS'
  description 'This is a plugin for iNia'
  version '0.0.1'
  url 'https://inia.objectfrontier.com/redmine'

  project_module :ticketing_approval_system  do
    permission :manage_ticketing_approval,{ :controller => 'CategoryApprovalConfigsController' }, :require => :member
    # permission :set_assignee_for_approval,{ :controller => 'CategoryApprovalConfigsController', :action => 'set_assignee' }, :require => :member
    # project_module :approval_level do

      permission :a1, :require => :member
      permission :a2, :require => :member
      permission :a3, :require => :member
      permission :a4, :require => :member
      permission :a5, :require => :member
      permission :a6, :require => :member
      permission :a7, :require => :member
    # end
  end

  RedmineApp::Application.config.after_initialize do
    require_dependency 'ticketing_approval_system/infectors'
  end
end
