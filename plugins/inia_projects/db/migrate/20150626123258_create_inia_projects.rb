class CreateIniaProjects < ActiveRecord::Migration
  def change
    create_table "inia_projects", :force => true do |t|
      t.string   "name",            :default => "",    :null => false
      t.text     "description"
      t.string   "homepage",        :default => ""
      t.boolean  "is_public",       :default => true,  :null => false
      t.integer  "parent_id"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.string   "identifier"
      t.integer  "status",          :default => 1,     :null => false
      t.integer  "lft"
      t.integer  "rgt"
      t.boolean  "inherit_members", :default => false, :null => false
    end

  end
end
