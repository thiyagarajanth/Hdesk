class AddColumnToDefaultAssignee < ActiveRecord::Migration
  def change
    add_column :default_assignee_setups, :status_id, :integer
    add_column :default_assignee_setups, :assignee, :string
  end
end
