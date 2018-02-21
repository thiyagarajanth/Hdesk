class AddTimestampsToSla < ActiveRecord::Migration

  def change
    change_table :issue_slas do |t|
      t.timestamps
    end
    change_table :issue_sla_statuses do |t|
      t.timestamps
    end
    change_table :sla_working_days do |t|
      t.timestamps
    end
    change_table :response_slas do |t|
      t.timestamps
    end
  end
end
