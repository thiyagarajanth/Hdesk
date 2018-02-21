class RequestRemainder < ActiveRecord::Base
  unloadable
  belongs_to :issue
  belongs_to :ticket_tag
  belongs_to :user
  belongs_to :project
end