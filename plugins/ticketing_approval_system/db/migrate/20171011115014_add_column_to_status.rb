class AddColumnToStatus < ActiveRecord::Migration
  def change
    add_column :project_categories, :dashboard_visibility, :boolean, :default => false
    add_column :issue_statuses, :dashboard_visibility, :boolean, :default => false
  end
end
