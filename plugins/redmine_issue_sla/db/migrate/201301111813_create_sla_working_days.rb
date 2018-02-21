class CreateSlaWorkingDays < ActiveRecord::Migration
  def change
    create_table :sla_working_days do |t|
      t.boolean :sun
      t.boolean :mon
      t.boolean :tue
      t.boolean :wed
      t.boolean :thu
      t.boolean :fri
      t.boolean :sat
      t.string :start_at
      t.string :end_at
      t.integer :project_id
      t.integer :tracker_id
    end
  end
end
