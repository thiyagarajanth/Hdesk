class AddAccessUsersToIssues < ActiveRecord::Migration
  def change
    add_column :issues, :access_users, :string, array: true, default: []
  end
end
