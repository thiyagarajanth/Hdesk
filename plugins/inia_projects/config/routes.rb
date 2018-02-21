#
get 'inia_members', :to => 'inia_members#index'
get 'inia_members/:id', :to => 'inia_members#index'
put 'inia_members/:id', :to => 'inia_members#update', :as => 'add_member_rols'
match 'inia_members/edit', :controller => 'inia_members', :action => 'edit', :via => [:get]
get 'inia_members/lacking_approvals', :to => 'inia_members#lacking_approvals'
get 'inia_members/group_users', :to => 'inia_members#group_users'

resources :inia_members do
  collection do
    get 'group_users'
    get 'lacking_approvals'
  end
end