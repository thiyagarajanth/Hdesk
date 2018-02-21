class CreateIniaMemberApprovalRoles < ActiveRecord::Migration
  def change
    create_table :approval_roles_inia_members do |t|

      t.integer :inia_member_id

      t.integer :approval_role_id
      t.timestamps null: false


    end

  end
end
