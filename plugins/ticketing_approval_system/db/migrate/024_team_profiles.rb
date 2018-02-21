class TeamProfiles < ActiveRecord::Migration
  def change
    create_table :team_profiles do |t|
      t.integer :project_id
      t.integer :user_id
      t.string :name
      t.string :designation
      t.integer :priority
      t.boolean :display
      t.timestamps
    end
  end
end
