class CreatePermanentUnlocks < ActiveRecord::Migration
  def change
    create_table :permanent_unlocks do |t|
      t.boolean :status
      t.integer :user_id
      t.text :comment
    end
  end
end
