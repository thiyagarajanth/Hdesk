class UserRating < ActiveRecord::Base
  belongs_to :issue
  belongs_to :user
  belongs_to :project

end