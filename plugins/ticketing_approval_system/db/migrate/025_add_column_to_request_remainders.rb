class AddColumnToRequestRemainders < ActiveRecord::Migration
  def change
    add_column :request_remainders, :project_id	, :integer
  end
end
