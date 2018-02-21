class CreateLockUserEntries < ActiveRecord::Migration
  def change
    create_table :lock_user_entries do |t|
      t.integer :user_id
      t.boolean :lock
      t.date :due_date
      t.datetime :created_at
    end
  end
end
