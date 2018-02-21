class UserUnlockHistory < ActiveRecord::Base
  unloadable
  belongs_to :user
  belongs_to :unlocked_user,:class_name => 'User', :foreign_key => :manager_id
end
