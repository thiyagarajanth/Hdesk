class AddColumnsToTicketTags < ActiveRecord::Migration
  def change
    add_column :ticket_tags, :validity	, :integer, :default => 0
  end
end
