class CreateResponseTimes < ActiveRecord::Migration
  def change
    create_table :response_times do |t|
      t.boolean :status, :default => false
      t.text :comment
      t.string :duration
      t.integer :issue_id
      t.integer :user_id
      t.datetime :created_at
      t.datetime :updated_at
    end
  end
end
