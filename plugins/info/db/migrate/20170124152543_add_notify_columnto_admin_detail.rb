class AddNotifyColumntoAdminDetail < ActiveRecord::Migration
  def change
    add_column :admin_details, :notify, :text
  end
end
