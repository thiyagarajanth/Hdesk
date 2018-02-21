class AddColumnToIssueSlaStatus < ActiveRecord::Migration
  def change
    add_column :issue_sla_statuses, :approval_sla, :boolean
  end
end
