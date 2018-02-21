class AddColumnToRespondSla < ActiveRecord::Migration
  def change
    unless column_exists? :response_slas, :ticket_closing
      add_column :response_slas, :ticket_closing, :integer
    end
  end

end