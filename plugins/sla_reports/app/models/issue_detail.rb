class IssueDetail < ActiveRecord::Base
  unloadable
  belongs_to :resolved_by, :class_name => "User", :foreign_key => :resolved_by
  belongs_to :issue

end
