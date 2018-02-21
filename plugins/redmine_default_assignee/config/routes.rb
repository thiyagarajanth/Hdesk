# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
# match '/default_assignee_setup/index', :to => 'default_assignee_setup#index', :via => [:get, :post]
# match '/default_assignee_setup/result', :to => 'default_assignee_setup#result', :via => [:get, :post]
resources :projects do
  resources  :default_assignee_setup
end

match 'default_assignee_setup/status_config', :to => 'default_assignee_setup#status_configuration', :via => :post