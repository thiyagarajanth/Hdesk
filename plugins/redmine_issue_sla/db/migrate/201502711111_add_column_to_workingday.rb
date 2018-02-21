class AddColumnToWorkingday < ActiveRecord::Migration
  def change
    add_column :sla_working_days, :break_from, :string
    add_column :sla_working_days, :break_to, :string
  end

end