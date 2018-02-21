require 'redmine'

require_dependency 'welcome_controller_patch'


WelcomeController.send(:include, WelcomeControllerPatch)

Redmine::Plugin.register :dashboard do
  name 'Dashboard plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'
end

RedmineApp::Application.config.after_initialize do
   require 'dashboard/infectors/my_helper'
end

Rails.configuration.to_prepare do
  require_dependency 'dashboard/infectors'
end
