class AddColumnToResponseSla < ActiveRecord::Migration
  def change
    add_column :response_slas, :auto_close, :integer
  end
end
