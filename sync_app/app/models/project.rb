class Project < ActiveRecord::Base
  # establish_connection "sync_prod"
  has_many :members
  has_many :issues
  has_many :enabled_modules, :dependent => :delete_all
end