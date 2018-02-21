class UserOfficialInfo < ActiveRecord::Base
  unloadable
  belongs_to :user
 
end
