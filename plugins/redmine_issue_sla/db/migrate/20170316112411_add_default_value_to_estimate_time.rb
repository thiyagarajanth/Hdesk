class AddDefaultValueToEstimateTime < ActiveRecord::Migration
  def change
    change_column :approver_slas, :estimated_time, :float, :default => 0
  end
end
