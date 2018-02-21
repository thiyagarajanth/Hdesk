class AddColumnToTagsCategories < ActiveRecord::Migration
  def change
    add_column :ticket_tags, :source, :string
    add_column :ticket_tags, :internal, :boolean, :default => true
    add_column :project_categories, :source, :string
    add_column :project_categories, :internal, :boolean, :default => true
  end
end
