class CreateTicketApprovalFlows < ActiveRecord::Migration
  def change
    create_table :ticket_approval_flows do |t|

      t.integer :issue_id
      t.integer :ticket_approval_id
      t.integer :user_id
      t.string :status
      t.text :notes
      t.timestamps null: false

    end

  end
end