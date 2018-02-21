class AddColumnToProject < ActiveRecord::Migration
  def change
  	add_column :projects, :dept_code, :string
  end
end
