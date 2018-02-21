class CreateTicketApprovals < ActiveRecord::Migration
  def change
    create_table :ticket_approvals do |t|

      t.integer :ticket_tag_id
      t.integer :approval_role_id
      t.integer :user_id
      t.boolean :can_override
      t.integer :ref_id
      t.timestamps null: false
    end

  end
end
