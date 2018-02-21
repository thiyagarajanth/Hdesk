class AddAggrementColumnToTicketTag < ActiveRecord::Migration
  def change
    add_column :ticket_tags, :have_agreement, :boolean, default: false
    add_column :ticket_tags, :agreement_code, :string
    add_column :ticket_tags, :agreement_name, :string
  end
end
