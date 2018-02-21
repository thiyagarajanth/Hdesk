class CreateUserOfficialInfos < ActiveRecord::Migration
  def change
    create_table :user_official_infos do |t|
      t.integer :user_id
      t.integer :employee_id
      t.string :company
    end
  end
end
