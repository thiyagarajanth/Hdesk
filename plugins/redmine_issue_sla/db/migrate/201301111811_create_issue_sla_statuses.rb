class CreateIssueSlaStatuses < ActiveRecord::Migration
  def change
    create_table :issue_sla_statuses do |t|
      t.integer :project_id
      t.integer :tracker_id
      t.integer :issue_status_id
      t.string :sla_timer, :default => 'stop'
    end
  end
end
