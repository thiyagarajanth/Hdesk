class IniaMemberNanbaRoles < ActiveRecord::Migration
  def change
    create_table :inia_member_nanba_roles do |t|
      t.integer  "member_id",           :default => 0,     :null => false
      t.integer  "role_id",        :default => 0,     :null => false
      t.integer "inherited_from"
      t.timestamps
    end
  end
end
