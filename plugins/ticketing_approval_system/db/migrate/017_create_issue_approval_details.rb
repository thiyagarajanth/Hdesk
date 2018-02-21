class CreateIssueApprovalDetails < ActiveRecord::Migration
  def change
    create_table :issue_approval_details do |t|

      t.integer :issue_id
      t.integer :approval_definition_id
      t.integer :user_id
      t.string :status
      t.string :user_type
      t.text :notes
      t.timestamps null: false

    end

  end
end
