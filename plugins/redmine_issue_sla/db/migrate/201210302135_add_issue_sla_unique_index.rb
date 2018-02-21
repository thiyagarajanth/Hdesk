class AddIssueSlaUniqueIndex < ActiveRecord::Migration
  def change
    #add_index :issue_slas, [:project_id, :priority_id,:tracker_id], :unique => true
  end

end
