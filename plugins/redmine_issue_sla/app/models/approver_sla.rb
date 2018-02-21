class ApproverSla < ActiveRecord::Base
  unloadable
  belongs_to :project
  belongs_to :tracker
  belongs_to :approval_role
  belongs_to :issue_priority, foreign_key: "priority_id"
  after_save :update_config
  before_save :log_changes
  after_destroy :check_record
  before_destroy :log_changes

  def log_changes
    @@values=''
    @@values = ApproverSla.find_or_initialize_by_id(self.id).attributes.values
    @@id = self.id
  end

  def check_record
    AuditConfig.create(:table_name => self.class.table_name, :entity_id => self.id,:entity_type => 'delete',
                       :field_name =>self.attributes.keys, :old_value => @@values,
                       :new_value =>'', :modified_value => {self.priority.name.to_sym =>'deleted'}.to_json,
                       :created_by => User.current.id, :created_at => Time.now, :project_id => self.project_id)
  end

  def update_config
    # changes = self.changes.except!(:created_at, :updated_at, :project_id, :tracker_id, :priority_id)
    changes = self.changes.select {|k,v| [ "estimated_time"].include?(k) && v[0].to_f !=v[1].to_f}
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



  def self.create_or_update(project, params)
    sla = params['approver_sla']
    sla.each do |key, value|
      priority = IssuePriority.find_by_name(key)
      value.each do |key, value|
        apsla = ApproverSla.find_or_initialize_by_project_id_and_tracker_id_and_approval_role_id_and_priority_id(project.id, params[:tracker_id],key, priority.id)
        apsla.estimated_time = value
        apsla.updated_at=params[:updated_at]
        apsla.save
      end
    end if sla
  end

end

