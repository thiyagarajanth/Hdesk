class CreateTableApproverSla < ActiveRecord::Migration
  def change
    create_table :approver_slas do |t|
      t.integer :project_id
      t.integer :priority_id
      t.integer :tracker_id
      t.integer :approval_role_id
      t.float :estimated_time
      t.timestamps
    end
  end
end
