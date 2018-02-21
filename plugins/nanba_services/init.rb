
require 'redmine'
require_dependency 'attachments_controller_patch'
AttachmentsController.send(:include, AttachmentsControllerPatch)


Redmine::Plugin.register :nanba_services do
  name 'Nanba Services plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'
end