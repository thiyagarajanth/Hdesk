class AddColumnToRoles < ActiveRecord::Migration
  def change
    add_column :roles, :ticketing_role, :boolean, :default => false
  end
end