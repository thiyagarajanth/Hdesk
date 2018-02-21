class CreateIniaMembers < ActiveRecord::Migration
  def change
    create_table :inia_members do |t|
      t.integer  "user_id",           :default => 0,     :null => false
      t.integer  "project_id",        :default => 0,     :null => false
      t.datetime "created_on"
      t.boolean  "mail_notification", :default => false, :null => false
      t.timestamps
    end
  end
end
