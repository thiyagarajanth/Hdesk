class CreateAdminDetails < ActiveRecord::Migration
  def change
    create_table :admin_details do |t|

      t.string :name

      t.string :email

      t.string :description


    end

  end
end
