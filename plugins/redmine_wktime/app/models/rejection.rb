class Rejection < ActiveRecord::Base
  unloadable
  belongs_to :project
  belongs_to :user
  belongs_to :rejected_user,:class_name => 'User', :foreign_key => :rejected_by
end
