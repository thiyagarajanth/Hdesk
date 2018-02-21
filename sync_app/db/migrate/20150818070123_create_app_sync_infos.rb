class CreateAppSyncInfos < ActiveRecord::Migration
  def change
    create_table :app_sync_infos do |t|
      t.string :name
      t.datetime :last_sync
      t.boolean :in_progress, :default => false

      t.timestamps
    end
  end
end
