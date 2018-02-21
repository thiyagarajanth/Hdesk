class CreateDefaultAssigneeSetups < ActiveRecord::Migration
  def change
    create_table :default_assignee_setups do |t|
      t.integer :project_id
      t.integer :tracker_id
      t.integer :default_assignee_to
      t.datetime :created_on
      t.datetime :updated_on
    end
  end
end
