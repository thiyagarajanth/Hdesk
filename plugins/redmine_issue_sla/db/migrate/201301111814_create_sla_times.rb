class CreateSlaTimes < ActiveRecord::Migration
  def change
    create_table :sla_times do |t|
      t.integer :issue_id
      t.integer :issue_sla_status_id
      t.integer :old_status_id
      t.float :pre_status_duration
      t.integer :user_id
      t.datetime :created_at
      t.datetime :updated_at
    end
  end
end
