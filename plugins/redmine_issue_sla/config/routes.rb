RedmineApp::Application.routes.draw do
  put '/projects/:project_id/issue_slas' => 'issue_slas#update'
  get 'issue_slas/ticket_sla', :to => 'issue_slas#ticket_sla'
  put '/projects/:project_id/appropver_sla', :to => 'issue_slas#appropver_sla'

  get 'issue_slas/add_response_sla', :to => 'issue_slas#add_response_sla'
  get '/projects/:project_id/issues/update_form1', :to => 'issues#update_form1'
  post '/projects/:project_id/issue_slas' => 'issue_slas#update'
  get '/projects/:project_id/issue_slas' => 'issue_slas#update'
end