class IssueSla < ActiveRecord::Base
  belongs_to :project, :class_name => 'Project', :foreign_key => 'project_id'
  belongs_to :priority, :class_name => 'IssuePriority', :foreign_key => 'priority_id'
  belongs_to :tracker, :class_name => 'Tracker', :foreign_key => 'tracker_id'
  validates_presence_of :priority, :project
  validates_numericality_of :allowed_delay, :allow_nil => true
  has_many :issues,:class_name => 'Issue', :foreign_key => 'priority_sla_id'
  attr_protected :priority_id, :project_id
  
  # before_save :update_issues

  after_save :update_config
  before_save :log_changes

  after_destroy :check_record
  before_destroy :log_changes


  def log_changes
    @@values=''
    @@values = IssueSla.find_or_initialize_by_id(self.id).attributes.values
    @@id = self.id
  end

  def check_record
    AuditConfig.create(:table_name => self.class.table_name, :entity_id => self.id,:entity_type => 'delete',
                       :field_name =>self.attributes.keys, :old_value => @@values,
                       :new_value =>'', :modified_value => {self.priority.name.to_sym =>'deleted'}.to_json,
                       :created_by => User.current.id, :created_at => Time.now, :project_id => self.project_id)
  end

  def update_config
    changes = self.changes.select {|k,v| ["allowed_delay"].include?(k) && v[0]!=v[1]}
    if changes.present?
      state = (self.id.present? ? 'update' : 'create')
      create_audit(changes, state)
    end
  end

  def create_audit(changes, state)
    old_value = @@id.present? ? @@values : ''
    AuditConfig.create(:table_name => self.class.table_name, :entity_id => self.id,:entity_type => state,
                       :field_name =>self.attributes.keys, :old_value => old_value,
                       :new_value =>self.attributes.values, :modified_value => {self.priority.name.to_sym =>changes.values.flatten }.to_json,
                       :created_by => User.current.id, :created_at => self.updated_at, :project_id => self.project_id)
  end

  # add severioty to project
  def self.create_slas(project, params)
     priority_ids = params[:priority_ids]
    tracker_id = params[:tracker_id]
    if priority_ids.present?
      priority_ids.each do |priority_id|
        if params[:issue_sla][priority_id.to_sym].present?
          issue_priority_id = IssueSla.where(:project_id=>project.id,:tracker_id=>tracker_id,:priority_id=>priority_id)
          if issue_priority_id.present?
            issue_priority_id.last.update_attributes(:allowed_delay => params[:issue_sla][priority_id.to_sym], :updated_at=>params[:updated_at])
          else
            issue_sla = IssueSla.new
            issue_sla.project_id = project.id
            issue_sla.tracker_id = tracker_id
            issue_sla.priority_id = priority_id.to_i
            issue_sla.allowed_delay = params[:issue_sla][priority_id.to_sym]
            issue_sla.updated_at=params[:updated_at]
            issue_sla.save
          end
          resolve = IssueStatus.find_by_name('Resolved')
  # p [resolve.id, priority_id]
  #         issues =  project.issues.open.where("status_id != #{resolve.id} and priority_id=#{priority_id}")
  #         sla_rec = IssueSla.where(:tracker_id => issues.last.tracker.id, :project_id => project.id, :priority_id => priority_id.to_i)
  #         issues.update_all(:estimated_hours =>sla_rec.last.allowed_delay )
          project.issues.open.where("status_id != #{resolve.id} and priority_id=#{priority_id}").each do |issue|
            sla_rec = IssueSla.where(:tracker_id => issue.tracker.id, :project_id => issue.project.id, :priority_id => priority_id.to_i)
            next if issue.estimated_hours == sla_rec.last.allowed_delay
            Issue.skip_callbacks = true
            issue.update_attributes(:estimated_hours => sla_rec.last.allowed_delay)
            Issue.skip_callbacks = false
          end
        else
          find_sla = IssueSla.find_or_initialize_by_project_id_and_tracker_id_and_priority_id(project.id, tracker_id, priority_id)
          find_sla.allowed_delay="0.0"
          find_sla.updated_at=params[:updated_at]
          find_sla.save
        end
      end
      not_found_slas =  IssueSla.where(:project_id=>project.id,:tracker_id=>tracker_id).where("priority_id  NOT IN (?)",priority_ids)
      if not_found_slas.present?
        not_found_slas.each do |not_found|
          not_found.destroy
        end
      end
    else
     IssueSla.destroy_all(:project_id=>project.id,:tracker_id=>tracker_id)
    end

  end

  def self.create_or_update_response_time(project,params)
    tracker_id = params[:tracker_id]
    response_time = "#{params[:response_hours]}.#{params[:response_min]}"
    ticket_closing = params[:ticket_closing]
    auto_close = params[:auto_close]
    response_sla =ResponseSla.find_or_initialize_by_project_id_and_tracker_id(project.id, tracker_id)
    response_sla.response_set_time = response_time
    response_sla.ticket_closing = ticket_closing
    response_sla.auto_close = auto_close
    response_sla.updated_at=params[:updated_at]
    response_sla.save
  end



  private
  def update_issues

    resolve = IssueStatus.find_by_name('Resolved')
    project.issues.open.where("priority_id = #{priority.id} and status_id != #{resolve.id} and estimated_hours != #{allowed_delay}").all.each do |issue|
      next if issue.first_response_date.present?
      issue.estimated_hours == allowed_delay

      date = nil
      if allowed_delay.present?
        date = allowed_delay.hours.since(issue.created_on).round
      end
      if issue.expiration_date != date
        issue.init_journal(User.current)
        issue.attributes_before_change['expiration_date'] = date
        Issue.skip_callbacks = true
        issue.expiration_date = date
        issue.issue_sla = allowed_delay
        issue.save
        Issue.skip_callbacks = false
      end
    end
  end
end
