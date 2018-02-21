# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
get '/sla_reports', :to => 'sla_reports#index'
# get '/response_sla', :to => 'sla_reports#response'
# get '/resolution_sla', :to => 'sla_reports#resolution'
# get '/get_not_met_sla_tickets', :to => 'sla_reports#get_not_met_sla_tickets'
# get '/get_not_met_sla_tickets_on_load', :to => 'sla_reports#get_not_met_sla_tickets_on_load'
  
  match 'sla_reports', :controller => 'sla_reports', :action => 'user_request_validity', :via => :get

  resources :projects do
    # get 'sla_reports(/:tab)', :action => 'index', :as => 'sla_reports'
     # match 'sla_reports', :controller => 'sla_reports', :action => 'user_request_validity', :via => :get

    resources :sla_reports do
      collection do
        get 'responses'
        get 'resolutions'
        get 'get_not_met_sla_tickets'
        get 'get_not_met_sla_tickets_on_load'
        get 'request_validity'
        get 'user_rating'

      end
    end
    #get 'sla_reports(/:tab)', :to => 'sla_reports#sla_reports', :as => 'sla_reports'
    # get 'sla_reports/responses', :to => 'sla_reports#responses', :as => 'response_sla'
    # get 'sla_reports/resolution', :to => 'sla_reports#resolution', :as => 'resolution_sla'
    # get 'sla_reports/get_not_met_sla_tickets', :to => 'sla_reports#get_not_met_sla_tickets', :as => 'get_not_met_sla_tickets'
    # get 'sla_reports/get_not_met_sla_tickets_on_load', :to => 'sla_reports#get_not_met_sla_tickets_on_load', :as => 'get_not_met_sla_tickets_on_load'
  end