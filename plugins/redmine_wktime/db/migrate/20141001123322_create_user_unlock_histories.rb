class CreateUserUnlockHistories < ActiveRecord::Migration
  def change
    create_table :user_unlock_histories do |t|
      t.integer :user_id
      t.integer :manager_id
      t.integer :updated_by
      t.string :expire_time
      t.string :comment
      t.string :date
      t.datetime :created_at
    end
  end
end
