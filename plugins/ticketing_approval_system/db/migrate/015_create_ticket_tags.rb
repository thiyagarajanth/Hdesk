class CreateTicketTags < ActiveRecord::Migration
  def change
    create_table :ticket_tags do |t|

      t.string :name

      t.integer :parent_id

      t.integer :tracker_id

      t.integer :project_id

      t.integer :category_id
      t.integer :root
      t.timestamps null: false


    end

  end
end
