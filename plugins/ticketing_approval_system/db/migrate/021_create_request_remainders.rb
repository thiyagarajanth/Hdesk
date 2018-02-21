class CreateRequestRemainders < ActiveRecord::Migration
  def change
    create_table :request_remainders do |t|

      t.integer :issue_id
      t.integer :user_id
      t.integer :ticket_tag_id
      t.boolean :mail_status, :default => true
      t.string :error_info
      t.integer :retry_attempts, :default => 0
      t.date :validity
      t.timestamps null: false
    end
  end
end
