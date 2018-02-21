require 'rubygems'
require 'rake'
require 'rufus/scheduler'#require_dependency 'sync_helper'

Redmine::Plugin.register :inia_projects do
  name 'Inia Projects plugin'
  author 'OFS Tech'
  description 'Assign NANBA role to iNia project members'
  version '0.0.1'

  def permission_checker(permission)
    proc {
      access = []
      IniaMember.where(user_id: User.current.id).each { |member|
        member.inia_roles.each { |role|
          access << role.permissions.include?(permission.to_sym) || role.permissions.include?(:nanba_config)
        }
      }
      User.current.admin? || access.include?(true)
    }
  end

  project_module :nanba_dev  do
    permission :nanba_config, :require => :member
  end


  menu :top_menu, :my_link, {:controller => 'inia_members', :action => 'index',:data=>'i'}, :caption => 'iNia Projects', :if =>  permission_checker('manage_members')
end
