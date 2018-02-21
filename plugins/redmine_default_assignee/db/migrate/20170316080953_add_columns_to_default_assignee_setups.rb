class AddColumnsToDefaultAssigneeSetups < ActiveRecord::Migration
  def change
    add_column :default_assignee_setups, :display_in_overview, :boolean, :default => false
  end
end
