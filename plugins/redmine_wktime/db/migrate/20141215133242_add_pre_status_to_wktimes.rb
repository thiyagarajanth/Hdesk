class AddPreStatusToWktimes < ActiveRecord::Migration
  def self.up
    add_column :wktimes, :pre_status, :string
  end

  def self.down
    remove_column :wktimes, :pre_status
  end
end
