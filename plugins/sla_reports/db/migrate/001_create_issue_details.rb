class CreateIssueDetails < ActiveRecord::Migration
  def change
    create_table :issue_details do |t|
      t.integer :issue_id
      t.integer :sla_duration
      t.integer :resolution_time
      t.boolean :is_met_sla
      t.integer :resolved_by
      t.text :remarks
      t.timestamps null: false

    end
  end
end
