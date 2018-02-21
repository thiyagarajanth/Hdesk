class AddColumnToIssue < ActiveRecord::Migration
  def change
    add_column :issues, :priority_sla_id, :integer
  end
end