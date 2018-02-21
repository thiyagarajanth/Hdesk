class CreateApprovalRoleUsers < ActiveRecord::Migration
  def change
    create_table :approval_role_users do |t|
      t.integer :approval_role_id, :null => false
      t.integer :inia_project_id, :null => false
      t.integer :user_id, :null => false
      t.integer :project_id, :null => false
      t.timestamps null: false
    end
  end
end
