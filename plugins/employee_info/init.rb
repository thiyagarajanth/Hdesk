
require 'employee_info/user_patch'

UsersController.send(:include, UsersControllerPatch)


Redmine::Plugin.register :employee_info do
  name 'Employee Info plugin'
  author 'OFS'
  description 'This is a plugin for iNia'
  version '0.0.1'
  url 'http://inia.objectfrontier.com'
  author_url 'http://inia.objectfrontier.com'
end
Rails.configuration.to_prepare do
 unless User.included_modules.include? EmployeeInfo::Patches::UserPatch
    User.send(:include, EmployeeInfo::Patches::UserPatch)
 end
end

ActionDispatch::Callbacks.to_prepare do
  require_dependency 'employee_info/hooks'
  #require_dependency 'clipboard_image_paste/attachment_patch'
end