class CreateUserUnlockEntries < ActiveRecord::Migration
  def change
    create_table :user_unlock_entries do |t|
      t.integer :user_id
      t.integer :manager_id
      t.integer :updated_by
      t.string :expire_time
      t.string :comment
      t.datetime :created_at
    end
  end
end
