class AddAcceptAgreementColumntoIssueTicketTag < ActiveRecord::Migration
  def change
  	add_column :issue_ticket_tags, :accept_agreement, :boolean, default: false
  end
end
