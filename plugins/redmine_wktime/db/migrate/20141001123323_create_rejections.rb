class CreateRejections < ActiveRecord::Migration
  def change
    create_table :rejections do |t|
      t.integer :user_id
      t.integer :project_id
      t.integer :rejected_by
      t.string :rejected_role
      t.string :date
      t.string :comment

      t.datetime :created_at
    end
  end
end
