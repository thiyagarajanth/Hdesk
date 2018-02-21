RedmineApp::Application.routes.draw do

  # resources :category_approval_configs
  # post 'category_approval_configs/add_category', :to => 'category_approval_configs#add_category'
  # /projects/#{params[:project_id]}/settings/ticketing_approval_system
  post 'approval_definitions/agreement_view', :to => 'approval_definitions#agreement_view'
post 'approval_definitions/agreement', :to => 'approval_definitions#agreement'
#post 'approval_definitions/agreementstatus', :to => 'approval_definitions#accept_agreement'
get 'category_approval_configs/group_users', :to => 'category_approval_configs#group_users'
get 'category_approval_configs/update_interruption', :to => 'category_approval_configs#update_interruption'

get 'approval_definitions/update_interruption', :to => 'approval_definitions#update_interruption'
get 'approval_definitions/group_users', :to => 'approval_definitions#group_users'
get 'approval_definitions/tag_duedate', :to => 'approval_definitions#tag_duedate'
get 'approval_definitions/tag_duedate', :to => 'approval_definitions#tag_duedate'
post 'issues/add_access_users', :to => 'ticketing_project_categories#add_access_users'
get 'ticketing_project_categories/autocomplete_for_user', :to => 'ticketing_project_categories#autocomplete_for_user'
post 'ticketing_project_categories/append', :to => 'ticketing_project_categories#append'
post 'ticketing_project_categories/update_access_users', :to => 'ticketing_project_categories#update_access_users'
# get 'issues/add_access_users',:to=>"issues#add_access_users"
match 'issues/add_access_users', :controller => 'issues', :action => 'add_access_users', :via => [:put, :post]
  resources :projects do
    match 'issues/ticket_form', :controller => 'issues', :action => 'ticket_form', :via => [:put, :post], :as => 'ticket_form'
    match 'issues/ticket_rating', :controller => 'issues', :action => 'ticket_rating', :via => [:put, :post], :as => 'ticket_rating'
    match 'issues/check_rating', :controller => 'issues', :action => 'check_rating', :via => [:get], :as => 'check_rating'
    match 'issues/avg_rating', :controller => 'issues', :action => 'avg_rating', :via => [:get], :as => 'avg_rating'

    resources :ticketing_project_categories
    resources :approval_roles
    resources :approval_definitions do
      collection  { post :import_categories}
      collection do
        get 'respond_ticket'
        post 'agreement'
        post 'set_tracker'
        post 'add_ticket_list'
        get 'associate_tickets'
        get 'get_tags'
        get 'filterTag'
        get 'tag_duedate'
        post 'manage_team_members'
        get 'get_assignable_users'
        get 'export_tags'
        get 'accept_agreement'

        # post 'import_categories'


      end
    end
    resources :category_approval_configs do
      collection do
        get 'respond_ticket'
        post 'set_tracker'
        post 'add_ticket_list'
        get 'associate_tickets'
      end
    end
  end
  #
  # get '/projects/:project_id/settings/ticketing_project_categories/ticketing_policy', :to => 'ticketing_project_categories#ticketing_policy'
  # get '/projects/:project_id/settings/ticketing_project_categories/approval_policy', :to => 'ticketing_project_categories#approval_policy'


end