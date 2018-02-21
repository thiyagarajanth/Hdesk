class IssueSlaStatus < ActiveRecord::Base

  belongs_to :project, :class_name => 'Project', :foreign_key => 'issue_sla_status_id'
  belongs_to :tracker, :class_name => 'Tracker', :foreign_key => 'issue_sla_status_id'
  belongs_to :issue_status, :class_name => 'IssueStatus'

  has_one :sla_time, :class_name => 'SlaTime', :foreign_key => 'issue_sla_status_id'

  has_one :parent_status, :class_name => "IssueSlaStatus",  :foreign_key => "old_status_id"
  # belongs_to :old_status, :class_name => "IssueSlaStatus",  :foreign_key => "old_status_id"


  after_save :update_config
  before_save :log_changes
  after_destroy :check_record
  before_destroy :log_changes



  def log_changes

    # self.approval_sla = false if self.approval_sla.nil?
    @@values=''
    @@values = IssueSlaStatus.find_or_initialize_by_id(self.id).attributes.values
    @@id = self.id
  end

  def check_record
    AuditConfig.create(:table_name => self.class.table_name, :entity_id => self.id,:entity_type => 'delete',
                       :field_name =>self.attributes.keys, :old_value => @@values,
                       :new_value =>'', :modified_value => {self.issue_status.name.to_sym =>'deleted'}.to_json,
                       :created_by => User.current.id, :created_at => Time.now, :project_id => self.project_id)
  end

  def update_config
    # changes = self.changes.except!(:created_at, :updated_at)
    # raise
    changes = self.changes.select {|k,v| ["sla_timer", "approval_sla"].include?(k) && v[0]!=v[1]}
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

  def self.create_project_status(project, params)
    p '===========================masgter=============='
    sla_status_ids, timer,tracker_id = params[:status_ids], params[:status_sla],params[:tracker_id]

    project.issue_sla_statuses.map(&:issue_status_id).each do |sla|
      unless sla_status_ids.present? && sla_status_ids.include?(sla.to_s)
        project.issue_sla_statuses.find_by_issue_status_id(sla).delete
      end
    end

    slas = project.issue_sla_statuses
    rec = []
    timer.each {|key, value| rec << key if value=='stop' }
    sla = sla_status_ids.present? ? sla_status_ids : []
    ::IssueStatus.find(sla).each do |p|
      next if slas.any? {|s| s.issue_status_id == p.id }
       state = IssueSlaStatus.find_or_initialize_by_issue_status_and_project_id(p, project)
       state.sla_timer = timer[state.issue_status.id.to_s]
       state.tracker_id=tracker_id
       state.updated_at=params[:updated_at]
       state.save
    end
#    project.issue_sla_statuses.find_all_by_issue_status_id(rec).each { |rec| rec.update_attributes(:sla_timer => 'stop') }
    project.issue_sla_statuses.each do |issue_sla|
      if rec.include? issue_sla.issue_status_id.to_s
        issue_sla.update_attributes(:sla_timer => 'stop',:updated_at=>params[:updated_at])
      else
        issue_sla.update_attributes(:sla_timer => 'start',:updated_at=>params[:updated_at])
      end
    end
    project.issue_sla_statuses.reload
  end




  # add severioty to project
  def self.create_or_update_status(project, params)
    p '==============ni=================='
     priority_ids = params[:status_ids]
    tracker_id = params[:tracker_id]
     if priority_ids.present?
        # IssueSlaStatus.where("id NOT IN (?) and project_id=#{project.id} and approval_sla=true",params[:approval_sla_ids]).update_all(:approval_sla => false)
       # IssueSlaStatus.where(:issue_status_id => params[:approval_sla_ids],:project_id => project.id).update_all(:approval_sla => true)
      priority_ids.each do |priority_id|
        find_sla = IssueSlaStatus.find_or_initialize_by_project_id_and_tracker_id_and_issue_status_id(project.id,tracker_id, priority_id)
        if params[:status_sla][priority_id.to_sym].present? && params[:status_sla][priority_id.to_sym] == "start"
          find_sla.sla_timer = 'start'
        else
          find_sla.issue_status_id=priority_id
          find_sla.sla_timer = 'stop'
        end
        old_st = find_sla.approval_sla
        st = ( params[:approval_sla_ids].present? && params[:approval_sla_ids].include?(find_sla.issue_status_id.to_s)) ? true : false
        if (old_st.nil? && st) || old_st == true || old_st == false
          find_sla.approval_sla = st
        end
        find_sla.updated_at=params[:updated_at]
        find_sla.save
        not_found_slas =  IssueSlaStatus.where(:project_id=>project.id,:tracker_id=>tracker_id).where("issue_status_id  NOT IN (?)",priority_ids)
        if not_found_slas.present?
          not_found_slas.each do |not_found|
            not_found.destroy
          end
        end
      end
    else
      IssueSlaStatus.destroy_all(:project_id=>project.id,:tracker_id=>tracker_id)
    end

  end





end
