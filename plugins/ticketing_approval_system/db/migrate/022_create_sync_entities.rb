class CreateSyncEntities < ActiveRecord::Migration
  def change
    create_table :sync_entities do |t|
    	t.string :entity 
    	t.integer :entity_id
    	t.string :ref_entity
    	t.boolean :can_sync, :default => false
    	t.datetime :last_sync_at
      t.timestamps
    end
  end
end
