class CreateApprovalRoles < ActiveRecord::Migration
  def change
    create_table :approval_roles do |t|
      t.string :name
      t.integer :level
      t.boolean :can_restrict
      t.integer :project_id
      t.integer :tracker_id
      t.timestamps null: false
    end
  end
end
