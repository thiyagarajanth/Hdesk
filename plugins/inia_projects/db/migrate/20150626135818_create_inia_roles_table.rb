class CreateIniaRolesTable < ActiveRecord::Migration
  def change
    create_table "inia_roles", :force => true do |t|
      t.string  "name",              :limit => 30, :default => "",        :null => false
      t.integer "position",                        :default => 1
      t.boolean "assignable",                      :default => true
      t.integer "builtin",                         :default => 0,         :null => false
      t.text    "permissions"
      t.string  "issues_visibility", :limit => 30, :default => "default", :null => false
    end
  end
end
