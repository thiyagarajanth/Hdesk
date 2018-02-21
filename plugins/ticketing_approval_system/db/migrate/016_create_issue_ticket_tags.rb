class CreateIssueTicketTags < ActiveRecord::Migration
  def change
    create_table :issue_ticket_tags do |t|
      t.integer :issue_id  
      t.integer :ticket_tag_id
      t.integer :inia_project_id
      t.timestamps null: false
    end
  end
end
