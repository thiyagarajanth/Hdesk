class CreateResponseSlas < ActiveRecord::Migration
  def change
    create_table :response_slas do |t|
      t.float :response_set_time
      t.integer :project_id
      t.integer :tracker_id
    end
  end
end
