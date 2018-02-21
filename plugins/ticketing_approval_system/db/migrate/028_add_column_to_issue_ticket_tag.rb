class AddColumnToIssueTicketTag < ActiveRecord::Migration
  def change
    add_column :issue_ticket_tags, :category_id, :integer
  end
end