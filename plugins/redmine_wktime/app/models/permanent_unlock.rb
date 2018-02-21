class PermanentUnlock < ActiveRecord::Base
  unloadable
  belongs_to :user
end
