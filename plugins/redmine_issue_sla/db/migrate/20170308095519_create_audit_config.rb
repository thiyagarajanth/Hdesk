class CreateAuditConfig < ActiveRecord::Migration
  def change
    create_table :audit_configs do |t|
      t.integer :project_id
      t.string :table_name
      t.integer :entity_id
      t.string :entity_type
      t.text :field_name
      t.text :old_value
      t.text :new_value
      t.text :modified_value
      t.integer :created_by
      t.datetime :created_at
    end
  end
end
