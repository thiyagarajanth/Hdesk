class UserRating < ActiveRecord::Migration
  def change
    create_table :user_ratings do |t|
      t.integer :project_id
      t.integer :issue_id
      t.integer :rated_for
      t.integer :rated_by
      t.integer :rating
      t.integer :max_rating
      t.timestamps
    end
  end
end
