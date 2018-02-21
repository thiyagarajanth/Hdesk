class Mapp::TicketsController < ApplicationController

  skip_before_filter :verify_authenticity_token,:authorize, :check_external_users
  before_filter :verify_message_api_key, :find_user
  before_filter :find_ticket,:validate_ticket, :except => :index
  before_filter :history_details, :only => :show
  before_filter :get_comments, :only => [:reject, :clarify]

  include ActionView::Helpers::DateHelper

  def index
    @issues = []
    if params["status"]==='pending'
      query = "select i.* from issues i, issue_statuses iss where assigned_to_id=#{@user.id} and (iss.name='waiting for approval' or iss.name='Need Clarification') and iss.id=i.status_id"
    elsif params["status"]==='author'
      query = "select * from issues where author_id=#{@user.id} "
    else
      render :json =>  { :errors => 'Unable to find the status in query parameter.'}
      return
    end
    issues = Issue.find_by_sql(query) if @user.present?
    issues.each do |issue|
      ticket = {}
      color_code = CustomValue.find_by_sql("select cv.value from custom_values cv, custom_fields cf, projects p where cv.customized_id=#{issue.project_id} and cv.custom_field_id=cf.id and cf.name='Color code' group by cv.customized_id ").map(&:value)[0]
      if issue.class != Hash
        inia_project = issue.inia_project.present? ? issue.inia_project.name : ''
        ticket.merge!(:dept_name => issue.project.name, :project_id => issue.project_id, :id => issue.id, :subject => issue.subject, :author => issue.author.name, :project_name => inia_project, :updated_on => issue.updated_on.localtime.strftime('%Y-%m-%d %H:%M:%S'),:priority_name => issue.priority.name, :dept_color => "##{color_code}")
        @issues << ticket
      end
    end
    render :json => @issues.to_json
  end

  def show
    pending =  @issue.status.name=='Waiting for approval'
    clarity =  @issue.ticket_approval_flows.where(:status => 'Information required').present? && @issue.status.name=='Need Clarification'
    approve =  @issue.project.enabled_modules.map(&:name).include?('ticketing_approval_system') && @issue.assigned_to == @user  && @issue.ticket_approval_flows.present?
    approve_btn = false
    reject_btn = false
    need_c =false
    provide_info = false
    if approve
      if pending && !clarity
        approve_btn = true
        need_c = true
      end
      if clarity && !pending
        provide_info=true
      end
      if clarity && @issue.author_id!=@user.id
        need_c=true
      end
      if pending || clarity
        reject_btn=true
      end
    end
    count = @issue.ticket_tag.validity
    due_date = @issue.due_date.present? ? @issue.due_date.strftime("%d-%b-%Y") : ''
    access_users = User.find(@issue.access_users).map(&:name).uniq
    ticket_details = {:ticket => {:dept_name => @issue.project.name, :ticket_id=>@issue.id, :created_by=> @issue.author.name,
                                  :project_name => (@issue.inia_project.name rescue ''), :created_on => @issue.created_on.strftime("%d-%b-%Y"),:priority => @issue.priority.name,
                                  :status => @issue.status.name, :category => (@issue.project_category.cat_name rescue ''),:validity_date => due_date,:max_vliadity => count,
                                  :subject => @issue.subject, :access_users => access_users, :description => @issue.description, :dept_color => "##{@color_code}" }
    }
    actions = {:buttons => {:approve => approve_btn, :clarification => need_c, :reject => reject_btn, :provide_information => provide_info}}
    render :json => {:result =>[ ticket_details,  @history,  actions ]}
  end

  def approve
    helper = Object.new.extend(CategoryApprovalConfigsHelper)
    approval = @issue.ticket_tag.ticket_approvals
    if (params[:due_date].present? && !@issue.due_date.present?) || (@issue.due_date.present? && @issue.due_date.strftime("%F") != params[:due_date])
      journal = Journal.create(journalized_id: @issue.id, journalized_type: 'Issue', user_id: @user.id,notes: ' .' )
      JournalDetail.create(journal_id: journal.id, property: "attr", prop_key: "due_date", old_value: @issue.due_date, value: params[:due_date])
      @issue.due_date = params[:due_date]
    end
    status = helper.approve_ticket(@issue, approval, params)
    @issue.save
    Mailer.deliver_issue_edit(@issue.journals.last)
    render :json => {result: {:success => status} }
  end

  def reject
    helper = Object.new.extend(CategoryApprovalConfigsHelper)
    approval = @issue.ticket_tag.ticket_approvals
    if params[:due_date].present? && @issue.due_date.present? && @issue.due_date.strftime("%F") != params[:due_date]
      journal = Journal.create(journalized_id: @issue.id, journalized_type: 'Issue', user_id: @user.id,notes: ' .' )
      JournalDetail.create(journal_id: journal.id, property: "attr", prop_key: "due_date", old_value: @issue.due_date, value: params[:due_date])
      @issue.due_date = params[:due_date]
    end
    status = helper.reject_ticket(@issue, approval, params)
    @issue.save
    Mailer.deliver_issue_edit(@issue.journals.last)
    render :json => {result: {:success => status} }
  end

  def clarify
    helper = Object.new.extend(CategoryApprovalConfigsHelper)
    approval = @issue.ticket_tag.ticket_approvals
    if params[:due_date].present? && @issue.due_date.present? && @issue.due_date.strftime("%F") != params[:due_date]
      journal = Journal.create(journalized_id: @issue.id, journalized_type: 'Issue', user_id: @user.id,notes: ' .' )
      JournalDetail.create(journal_id: journal.id, property: "attr", prop_key: "due_date", old_value: @issue.due_date, value: params[:due_date])
      @issue.due_date = params[:due_date]
    end
    status = helper.clarification_ticket(@issue, approval, params)
    @issue.save
    Mailer.deliver_issue_edit(@issue.journals.last)
    render :json => {result: {:success => status} }
  end

  # ============= calbacks ==================

  def verify_message_api_key
    if request.present? && request.headers["key"].present? && (request.headers["employee-id"].present? || params[:employeeId].present?)
      find_valid_key = Redmine::Configuration['mapp_api_key'] || File.join(Rails.root, "files")
      find_valid_key1 = Redmine::Configuration['hrms_api_key'] || File.join(Rails.root, "files")
      (find_valid_key == request.headers["key"].to_s || find_valid_key1 == request.headers["key"].to_s ) ? true : (render :json => {:errors =>'Invalid key'})
    else
      msg = ''
      if !request.headers["key"].present?
        msg = "Key not found"
      end
      if !request.headers["employee-id"].present? || !params[:employeeId].present?
        msg = msg.present? ? msg+" and " : msg
        msg =msg + " Employee ID not found."
      end
      render :json => {:errors =>msg}
    end
  end

  def find_user
    employee_id = request.headers["employee-id"] ? request.headers["employee-id"] : params[:employeeId]
    params.merge!(:employee_id => employee_id)
    params.merge!(:issue_id => params[:id])
    params.merge!(:comment => params[:comments])
    params.merge!(:due_date => params[:valid_till])
    info = UserOfficialInfo.find_by_employee_id(params[:employee_id])
    response = {}
    if info.present?
      @user = info.user
      params.merge!(:user_id => @user.id)
    else
      response.merge!( {:errors => 'Unable to find the user, Please check your Employee ID', :status => 500, :layout => nil} )
      render :json => response
    end
  end

  def find_ticket
    @issue = Issue.find(params[:id]) if params[:id].present?
    if !@issue.present?
      response.merge!( :errors => 'Unable to find ticket.' , :status => 500, :layout => nil)
      render :json => response
    end
  end

  def validate_ticket
    # p @user.id != @issue.assigned_to_id
    if (@user.present? && @issue.present?) && @user.id != @issue.assigned_to_id
      response = { :errors => 'This ticket not assigned to you.'}
      render :json => response
    end
  end

  def history_details
    helper = Object.new.extend(IssuesHelper)
    history = []
    @color_code = CustomValue.find_by_sql("select cv.value from custom_values cv, custom_fields cf, projects p where cv.customized_id=#{@issue.project_id} and cv.custom_field_id=cf.id and cf.name='Color code' group by cv.customized_id ").map(&:value)[0]
    begin
      @issue.journals.order('created_on desc').each do |journal|
        user = journal.user
        detail = helper.details_to_strings(journal.details, true)
        user = "#{user.firstname} #{user.lastname}, updated, #{distance_of_time_in_words(Time.now, journal.created_on)} ago."
        history << {:user => user, :details => detail, :notes => journal.notes }
      end
      history
    rescue
      history
    end
    @history =  {:history => history}
  end

  def get_comments
    if !params[:comments].present?
      render :json => {result: { :errors => 'Please enter comments to reject this ticket.', :success => false }}
    end
  end

end