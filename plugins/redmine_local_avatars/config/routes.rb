constraints(:id=>/\d+/) do
  get 'my/avatar/edit', :to => 'my#avatar_edit', :as => 'edit_my_avatar'
  post 'users/:id/avatar/upload.:format', :to => 'avatar#upload', :as => 'avatar_upload'
  get 'users/:id/avatar', :to => 'avatar#show', :as => 'user_avatar'
  match 'users/:id/avatar', :to => 'avatar#update', :as => 'update_user_avatar', via: [:put, :post]
  delete 'users/:id/avatar', :to => 'avatar#destroy', :as => 'destroy_user_avatar'
end
