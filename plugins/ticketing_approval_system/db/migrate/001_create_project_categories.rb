class CreateProjectCategories < ActiveRecord::Migration
  def change
    create_table :project_categories do |t|
      t.integer :project_id, :null => false
      t.string :cat_name, :null => false
      t.boolean :need_approval
    end
  end
end
