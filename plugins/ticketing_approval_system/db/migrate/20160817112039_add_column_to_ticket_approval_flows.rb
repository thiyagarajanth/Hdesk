class AddColumnToTicketApprovalFlows < ActiveRecord::Migration
  def change
    add_column :ticket_approval_flows, :waiting_time, :string
  end
end
