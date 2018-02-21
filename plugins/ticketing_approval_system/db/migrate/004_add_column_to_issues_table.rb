class AddColumnToIssuesTable < ActiveRecord::Migration
  def self.up
    add_column :issues, :pre_status_id, :string
  end

  def self.down
    remove_column :issues, :pre_status_id
  end
end
