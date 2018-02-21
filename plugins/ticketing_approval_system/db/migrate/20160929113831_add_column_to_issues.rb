class AddColumnToIssues < ActiveRecord::Migration
  def change
    add_column :issues, :is_system_created, :boolean, :default => false
  end
end
