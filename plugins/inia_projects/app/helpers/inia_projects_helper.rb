module IniaProjectsHelper
  def inia_projects_settings_tabs
    if User.current.admin? || User.current.projects_by_role.keys.map(&:permissions).flatten.include?(:nanba_config)
      tabs = [{:name => 'projects',  :partial => 'inia_members/projects', :data=>'p', :label => :label_projects},
              {:name => 'Config', :partial => 'inia_members/config', :data=>'c', :label => :label_config},
             # {:name => 'lacking_workflow', :partial => 'inia_members/lacking_workflow', :data=>'w', :label => :label_lack_workflow},
      ]
    else
      tabs = [{:name => 'projects',  :partial => 'inia_members/projects', :data=>'p', :label => :label_projects},
      ]
    end
  end
end
