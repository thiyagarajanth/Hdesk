class ResponseSla < ActiveRecord::Base
  unloadable
  belongs_to :tracker, :class_name => 'Tracker', :foreign_key => 'tracker_id'


  after_save :update_config
  before_save :log_changes


  def log_changes
    p '=================self==='
    p self
    @@values=''
    @@values = ResponseSla.find_or_initialize_by_id(self.id).attributes.values
    @@id = self.id
  end

  def update_config
    # changes = self.changes.except!(:created_at, :updated_at)
    changes = self.changes.select {|k,v| ["response_set_time", "ticket_closing","auto_close"].include?(k) && v[0]!=v[1] }
    if changes.present?
      id = self.id rescue nil
      old_value = @@id.present? ? @@values : ''
      state = (@@id.present? ? (id.present? ? 'update' : 'delete') : 'create')
      AuditConfig.create(:table_name => self.class.table_name, :entity_id => self.id,:entity_type => state,
                         :field_name =>self.attributes.keys, :old_value => old_value,
                         :new_value =>self.attributes.values, :modified_value => changes.to_json,
                         :created_by => User.current.id, :created_at => self.updated_at, :project_id => self.project_id)
    end
  end

end
