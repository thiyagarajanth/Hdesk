class CreateInialogtimes < ActiveRecord::Migration
  def change
    create_table :inialogtimes do |t|
      t.integer :user_id
      t.datetime :due_date
      t.datetime :locked_date
      t.boolean :status
      t.integer :manager_id
      t.text :notes
      t.integer :lock_version
    end
  end
end
