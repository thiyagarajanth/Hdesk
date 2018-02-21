class ApiTicketsController < ApplicationController
  unloadable
  respond_to  :json
  skip_before_filter :verify_authenticity_token,:authorize, :check_external_users, :cleanup_approvers
  before_filter :find_project_tracker,:only=>[:create, :create_ticket_with_attachment]
  before_filter :validate_priority_and_date, :only => [:create]
  before_filter :check_detection_params, :only => [:create_update_category, :create_update_tags, :tag_category_statuses]
  before_filter :check_status, :only => :close_ticket
  before_filter :validate_params, :only => :close_ticket
  before_filter :verify_message_api_key, :only => :open_tickets_count
  def index

  end


  def create
    p '------cretae'
    @messages = []
    @issue = Issue.new
    @issue.project_id=@project.id
    @issue.tracker_id=@tracker.id
    @issue.subject = params[:subject]
    @issue.author_id=@author.id
    @issue.description =params[:description]
    @issue.is_system_created = true

    has_ticket = Redmine::Plugin.registered_plugins.keys.include?(:ticketing_approval_system)
    if has_ticket.present?
      #needed_approval = ProjectCategory.find(@category.id).need_approval
    end
  #if !needed_approval || (approval_infos.present? && have_approval) || !approval_infos.present?
    if @issue.save!(:validate => false)
      tag = TicketTag.find_by_name(params[:subject])
      IssueTicketTag.create(:issue_id => @issue.id, :inia_project_id => @for_project.id, :ticket_tag_id => "")
      Issue.set_callback(:create, :after, :send_notification)
      if has_ticket && @issue.tracker.core_fields.include?('approval_workflow')
         project_id = @for_project.id
        # if needed_approval && tag.present? && approval_infos.count >= 1
        #   @issue.ticket_need_approval(approval_infos)
        #   Mailer.deliver_issue_add(@issue)
        # else
          default_assignee =  DefaultAssigneeSetup.find_by_project_id_and_tracker_id(@issue.project_id, @issue.tracker_id)
          default_assignee = default_assignee.present? ? default_assignee : DefaultAssigneeSetup.new
          @issue.assigned_to_id = default_assignee.default_assignee_to
          comments = params[:comment].present? ? params[:comment] : '.'
          journal =  Journal.create(journalized_id: @issue.id, journalized_type: 'Issue', user_id: @author.id,notes: comments )
          old_status = IssueStatus.find_by_name('new')
          status = IssueStatus.find_by_name('open')
          JournalDetail.create(journal_id: journal.id, property: "attr", prop_key: "status_id", old_value: old_status.id, value: status.id)
          @issue.status_id = status.id
          # @priority and @validity obtained by before filter validate_priority_and_date
          @issue.priority_id = @priority.id if @priority.present?
          @issue.due_date = @validity if @validity.present?
          @issue.save
          Mailer.deliver_issue_add(@issue)
        # end
      end
      call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
      render_json_ok(@issue)
    else
      render_validation_errors(@issue)
    end
  Issue.set_callback(:create, :after, :send_notification)
  end

  def create_update_category
    name = params[:oldName].present? ? params[:oldName] : params[:name]
    dep = Project.find_by_identifier(params[:depName])
    pc = ProjectCategory.find_or_initialize_by_project_id_and_cat_name((dep.id rescue nil),name)
    pc.need_approval = true
    pc.internal = false
    # pc.source = source
    pc.cat_name = params[:name]
    begin
      pc.save
      render :json => {:id=>pc.id, :name => pc.cat_name}, :status => 200, :layout => nil
    rescue
      render :json => {:error=>pc.errors}, :status => 200, :layout => nil
    end

  end

  def create_update_tags
    name = params[:oldName].present? ? params[:oldName] : params[:name]
    dep = Project.find_by_identifier(params[:depName])
    cat = ProjectCategory.find_or_initialize_by_project_id_and_cat_name(dep.id,params[:categoryName])
    tag = TicketTag.find_or_initialize_by_project_id_and_name_and_category_id(dep.id , name, cat.id )
    begin
      # tag.source = source
      tag.root=1
      tag.name = params[:name]
      tag.internal = false
      tag.save
      render :json => {:id=>tag.id, :name => tag.name}, :status => 200, :layout => nil
    rescue
      render :json => {:error=>"Something went wrong."}, :status => 200, :layout => nil
    end
  end

  def tag_category_statuses
    helper = Object.new.extend(DashboardHelper)
    a,b,c = helper.get_approval_statuses
    dep = Project.find_by_identifier(params[:depName])
    cat = ProjectCategory.find_or_initialize_by_project_id_and_cat_name(dep.id, params[:categoryName])
    if params[:type]=='category'
     issues =  Issue.find_by_sql("select * from issues i join issue_ticket_tags itt on i.id=itt.issue_id
join ticket_tags tt on itt.ticket_tag_id=tt.id join project_categories pc on pc.id=tt.category_id
where i.status_id in (#{a.present? ? a : ''},#{b.present? ? b : '' },#{c.present? ? c : ''}) and pc.id=#{cat.id} ")
     render :json => {:status=>issues.count == 0}, :status => 200, :layout => nil
    elsif params[:type]=='tag'
      tag = TicketTag.find_or_initialize_by_project_id_and_name_and_category_id((dep.id rescue nil),params[:name],  (cat.id rescue nil))
      if tag.id.present?
        issues =  Issue.find_by_sql("select * from issues i join issue_ticket_tags itt on i.id=itt.issue_id join ticket_tags tt on itt.ticket_tag_id=#{tag.id} where i.status_id in (#{a.present? ? a : ''},#{b.present? ? b : '' },#{c.present? ? c : ''}) and tt.id=#{tag.id} ")
        render :json => {:status=>issues.count == 0}, :status => 200, :layout => nil
      else
        render :json => {:status=>"Tag not found"}, :status => 200, :layout => nil
      end
    else
      render :json => {:status=>"Type not found"}, :status => 200, :layout => nil
    end
  end

  def create_ticket_with_attachment
    @issue = Issue.new
    @issue.project_id=@project.id
    @issue.tracker_id=@tracker.id
    @issue.subject = params[:subject]
    @issue.author_id=@author.id
    @issue.description =params[:description]
    @issue.is_system_created = true
    if @issue.save!(:validate => false)
      IssueTicketTag.create(:issue_id => @issue.id, :inia_project_id => @for_project.id, :ticket_tag_id => "")
     # Issue.set_callback(:create, :after, :send_notification)
      #----------------------------------------------
      # file = File.join(Rails.root, 'app', 'Affiliate_API.xls')
      # raw = File.read(file)
      # file_name =  File.basename(file)
      # @attachment = Attachment.new(:file => raw)
      # @attachment.author = @author
      # @attachment.filename = 'DC.csv'.presence || Redmine::Utils.random_hex(16)
      # @attachment.save
      #
      if params[:attachment].present?
        begin
          file = params[:attachment].tempfile
          raw = File.read(file)
          file_name =  params[:attachment].original_filename
          @attachment = Attachment.new(:file => raw)
          @attachment.author = @author
          @attachment.filename = file_name.presence || Redmine::Utils.random_hex(16)
          @attachment.save
          attachment = {"1"=>{"filename"=>file_name, "description"=>"", "token"=>@attachment.token}}
          @issue.save_attachments(attachment)
        rescue
          render_json_errors('Failed to create attachment')
        end
      end
      #----------------------------------------------
        default_assignee =  DefaultAssigneeSetup.find_by_project_id_and_tracker_id(@project.id, @tracker.id)
        default_assignee = default_assignee.present? ? default_assignee : DefaultAssigneeSetup.new
        @issue.assigned_to_id = default_assignee.default_assignee_to
        #journal =  Journal.create(journalized_id: @issue.id, journalized_type: 'Issue', user_id: User.current.id,notes: comments )
        old_status = IssueStatus.find_by_name('new')
        status = IssueStatus.find_by_name('open')
        #JournalDetail.create(journal_id: journal.id, property: "attr", prop_key: "status_id", old_value: old_status.id, value: status.id)
        @issue.status_id = status.id
        @issue.save
        #Mailer.deliver_issue_add(@issue)
        call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
        render_json_ok(@issue)
    else
      render_validation_errors(@issue)
    end
    #Issue.set_callback(:create, :after, :send_notification)
  end

  def close_ticket
    # @status value obtained by before filter check status method
    errors = []
    if (params[:ticketId].present? || params[:id].present?)
      id = params[:ticketId].present? ? params[:ticketId] : params[:id]
      ticket = Issue.find(id)

      #project = Project.find_by_dept_code(params[:deptCode])
      if @project.present?
        if @project.id == ticket.project_id
          comments = params[:comments].present? ? params[:comments] : ''
          requested_user = UserOfficialInfo.find_by_employee_id(params[:requesterId])
          if requested_user.present?
            user = User.find(requested_user.user_id)
            ticket.init_journal(user ,comments)
            ticket.status_id = @status.id if @status.present?
            if ticket.save(validate: false)
              render_json_ok(ticket)
            else
              render_json_errors(ticket.errors)
            end
          else
            errors <<  "Employee not found"
          end
        else
          errors << "Deptcode doesn't match for requested Issue"
        end
      else
        errors << "Invalid Deptcode"
      end
    else
      errors << "Ticket Id required..!"
    end
    if errors.present?
      render_json_errors(errors)
    end
  end

  def cleanup_approvers
    p '===================calle--------------------'
    ApprovalRoleUser.where(:user_id => params[:user_id], :inia_project_id => params[:project_id]).destroy_all
    tickets = Issue.find_by_sql("SELECT s.id FROM issues s join issue_ticket_tags it on s.id=it.issue_id  join issue_sla_statuses ss on s.status_id=ss.issue_status_id where ss.approval_sla=true and s.assigned_to_id=#{params[:user_id]} and it.inia_project_id=#{params[:project_id]} group by s.status_id").map(&:id)
    tickets.each do |id|
      ticket = Issue.find(id)
      ticket.assigned_to_id = nil
      ticket.init_journal(User.find_by_login('admin'), 'Approver has been Removed from requested project, Please contact your manager. ')
      # ticket.status_id = IssueStatus.find_by_name('Rejected').id
      ticket.save
    end
    p '==================cool =========================='
  end

  def ticket_status
    if params[:ticketIds].present?
      rec = []
      results = []
      issues = Issue.where(:id => params[:ticketIds].split(',')) rescue nil
      if issues.present?
        issues.map{|x| rec << [x.id,x.subject, x.status.name, x.project.dept_code]  }
        rec.each do |r|
          results << {:ticket_id => r[0], :dept_code => r[3], :subject => r[1], :status => r[2] }
        end
        render :json => {:tickets => results }, :status => 200, :layout => nil
      else
        render :json => {:status=>"Requested Tickets not found."}, :status => 404, :layout => nil
      end
    else
      render :json => {:status=>"Ticket Ids missing."}, :status => 404, :layout => nil
    end
  end

  def open_tickets_count
    departments = []
    dgo_departments = []
    results = []
    color_code_id = CustomField.find_by_name('color code').id
    dashboard_visibility_id = CustomField.find_by_name('Dashboard Visibility').id
    Project.all.each do |project|
      otikets=[]
      Issue.find_by_sql("select count(*) as count,sum(if(i.author_id=i.assigned_to_id,1,0)) as bo,
                            sum(if(i.author_id!=i.assigned_to_id,1,0)) as dgo from issues i
                            join issue_statuses si on si.id=i.status_id
                            where i.project_id=#{project.id} and si.name not in ('Resolved', 'Closed', 'Need Clarification','Accept Agreement', 'Rejected','Waiting for approval')
                            ").map{|x| otikets = [x.count,x.bo, x.dgo]  }
      color_code = Project.find_by_sql("select * from projects join custom_values on projects.id = custom_values.customized_id
                   WHERE custom_values.custom_field_id=#{color_code_id} and custom_values.customized_id=#{project.id}").compact.map(&:value)
      dashboard_visibility = Project.find_by_sql("select * from projects join custom_values on projects.id = custom_values.customized_id
                   WHERE custom_values.custom_field_id=#{dashboard_visibility_id} and custom_values.customized_id=#{project.id}").compact.map(&:value).last
      if dashboard_visibility == "1"
        if project.dept_code == "DGO"
          dgo_departments << {:count => otikets[0],:bo => (otikets[1].nil? ? 0 : otikets[1]) ,:dgo => (otikets[2].nil? ? 0 : otikets[2]),:name => project.name,:color_code => color_code.last,:identifier => project.identifier}
        else
          departments << {:count => otikets[0],:name => project.name,:color_code => color_code.last,:identifier => project.identifier }
        end
      end
    end
    results << {:dept => departments,:dgo => dgo_departments}
    render :json => results, :status => 200, :layout => nil
  end


  def nanba_open_ticket_dashboard
    departments = []
    nanba =  ActiveRecord::Base.establish_connection(:production).connection
    tickets = nanba.execute("CALL getOpenTicketsInDashboard()")
    if tickets.present?
      tickets = tickets.each(:as => :hash)
      tickets.each do |rec|
        priority=[]
        rec['priority'].split(',').each do |x|
          v = x.split('!')
          case
            when v[0]=='Critical Impact'
              color ='#b20000'
            when v[0]=='Significant Impact'
              color='#ff8247'
            when v[0]=='Minor Impact'
              color='#698b22'
          end
          priority << {:name => v[0],:count => v[1],:color => color}
        end
        ActiveRecord::Base.connection.reconnect!
        ip = IssuePriority.all.map(&:name)
        ip_names =  priority.map{|x|x[:name]}
        ip_new = ip - ip_names
        ip_new.each do |x|
          case
            when x=='Critical Impact'
              color ='#b20000'
            when x=='Significant Impact'
              color='#ff8247'
            when x=='Minor Impact'
              color='#698b22'
          end
          priority << {:name => x,:count => 0,:color => color}
        end
        status=[]
        rec['status'].split(',').each do |x|
          v = x.split('!')
          if v[0]=='On Hold' or v[0]=='Reopen'
            color ='#b20000'
          else
            color='#698b22'
          end
          status << {:name => v[0],:count => v[1],:color => color}
        end
        ActiveRecord::Base.connection.reconnect!
        istatus = IssueStatus.where(:dashboard_visibility => true).map(&:name)
        status_names =  status.map{|x|x[:name]}
        astatus = istatus - status_names
        astatus.each do |x|
          if x=='On Hold' or x=='Reopen'
            color ='#b20000'
          else
            color='#698b22'
          end
          status << {:name => x,:count => 0,:color => color}
        end
        category=[]
        rec['category'].split(',').each do |x|
          v = x.split('!')
            color='#698b22'
          category << {:name => v[0],:count => v[1],:color => color}
        end
        ActiveRecord::Base.connection.reconnect!
        pc = ProjectCategory.where(:project_id => rec['project_id'], :dashboard_visibility => true).map(&:cat_name)
        cat_names =  category.map{|x|x[:name]}
        pc_cat =  pc - cat_names
        pc_cat.each do |x|
          category << {:name => x,:count => 0,:color =>'#698b22'}
        end
        ActiveRecord::Base.connection.reconnect!
        sla_tickets=[]
        Issue.find_by_sql("select project_id,count(*) as total, sum(if(state='met',1,0)) as metSla, sum(if(state='not',1,0)) as notMet from (select i.project_id,i.id,if(0<((i.estimated_hours*60) - (sum(st.pre_status_duration)/100)*60),'met','not') as state from journals as j join issues i on i.id=j.journalized_id join sla_times st on st.issue_id=i.id join journal_details as jd on j.id=jd.journal_id and jd.prop_key='status_id' and jd.value in (select id from issue_statuses where name in ('Resolved')) and DATE_FORMAT(j.created_on, '%Y-%m-%d')=DATE(NOW()) and project_id=#{rec["project_id"]} group by i.id) ip group by project_id").map{|x|sla_tickets = [x.total, x.metSla, x.notMet]}
        sla = []
        sla << {:name => 'Resolved',:count => (sla_tickets[0].nil? ? 0 : sla_tickets[0]), :color => '#ff8247'}
        sla << {:name => 'Not Met SLA',:count => (sla_tickets[2].nil? ? 0 : sla_tickets[2]), :color => '#b20000'}
        sla << {:name => 'Met SLA',:count => (sla_tickets[1].nil? ? 0 : sla_tickets[1]), :color => '#698b22'}
        departments << {:name => rec["name"],
                        :total => rec["total"],
                        :sla_count => (sla_tickets[0].nil? ? 0 : sla_tickets[0]),
                        :priority => priority,
                        :category => category,
                        :status => status, :sla => sla        }
      end
      ActiveRecord::Base.connection.reconnect!
      render :json => {:depts => departments}, :status => 200, :layout => nil
    else
      ActiveRecord::Base.connection.reconnect!
      render :json => "No results found..!", :status => 200, :layout => nil
    end
  end

  def check_user_approval
    if params[:employeeId].present?
      aru = ApprovalRoleUser.find_by_sql("select count(ar.id) as count from approval_role_users ar join users u on u.id=ar.user_id
                                    join user_official_infos uo on uo.user_id=u.id where uo.employee_id=#{params[:employeeId]}").map(&:count)[0]
      ticket = Issue.find_by_sql("select count(i.id) as count  from issues i join issue_sla_statuses iss on iss.issue_status_id=i.status_id
                          join users u on u.id=i.assigned_to_id join user_official_infos uo on uo.user_id=u.id
                          where iss.approval_sla=1 and i.author_id != i.assigned_to_id and uo.employee_id=#{params[:employeeId]}").map(&:count)[0]
      res = (aru > 0 || ticket > 0)
      render :json => {:status => res}, :status => 200, :layout => nil
    else
      render :json => {:error => 'Employee Id not found.'}, :status => 404, :layout => nil
    end
  end

  private

  def check_detection_params
    errors = []
    unless params[:name].present?
      errors << "Name Not found"
    end
    if params[:depName].present?
      project = Project.find_by_identifier(params[:depName])
      unless project.present?
        errors << "Department Name Not found in the list"
      end
    else
      errors << "Department Name Not found"
    end
    if errors.present?
      render_json_errors(errors)
    end
  end

  def verify_message_api_key
    if request.present? && request.headers["key"].present?
        find_valid_key = Redmine::Configuration['hrms_api_key'] || File.join(Rails.root, "files")
       (find_valid_key == request.headers["key"].to_s) ? true : render_json_errors("Key Invalid.")
    else
      render_json_errors("Key not found in Url.")
    end
  end

  def find_project_tracker
    errors=[]
    if params[:deptCode].present?
      @project = Project.find_by_dept_code(params[:deptCode])
      if !@project.present?
        errors << "Invalid deptcode..!"
      end
    elsif params[:deptName].present?
      @project = Project.find_by_identifier(params[:deptName])
      if !@project.present?
        errors << "Invalid Identifier..!"
      end
    else
      errors <<  "Dept code or Name is required."
    end
    if @project.present?
      @tracker = Tracker.find_by_name(@project.name)
    end
    if !params[:employeeId].blank?
      author = UserOfficialInfo.find_by_employee_id(params[:employeeId])
    if author.present?
      @author = author.user
    else
      errors << "Employee Id Not found"
    end
    else
      errors << "Employee Id required..!"
    end

    if !params[:project].blank?
      @for_project=IniaProject.find_by_identifier(params[:project])
      unless @for_project
        @for_project=IniaProject.find_by_name(params[:project])
        unless @for_project
          errors << "Project Not Found..!"
        end
      end
    else
      errors << "Project required..!"
    end
    if !params[:category].blank?
      @category =ProjectCategory.find_by_cat_name_and_project_id(params[:category],@project.id) rescue nil
      unless @category
        errors << "Category Not Found..!"
      end
    else
      errors << "Category required..!"
    end
    if @author.present? && @for_project.present?
      member = IniaMember.find_by_user_id_and_project_id(@author.id,@for_project.id)
        unless member
          @for_project=IniaProject.find_by_name(params[:project])
          if @for_project.present?
            member = IniaMember.find_by_user_id_and_project_id(@author.id,@for_project.id)
            unless member
              errors << "Requested person is not a member of project..!"
            end
          else
            errors << "Requested person is not a member of project..!"
          end
        end
    end
    if errors.present?
      render_json_errors(errors)
    end
   
  end

  def check_status
    if params[:status].present?
      @status = IssueStatus.find_by_name(params[:status])
      unless @status.present?
        render :json => "Invalid status..!"
      end
    else
      render :json => "Status required..!"
    end
  end

  def validate_params
    errors = []
    unless params[:requesterId].present?
      errors <<  "requesterId required..!"
    end

    if params[:deptCode].present?
      @project = Project.find_by_dept_code(params[:deptCode])
      if !@project.present?
        errors << "Invalid deptcode..!"
      end
    elsif params[:deptName].present?
      @project = Project.find_by_identifier(params[:deptName])
      if !@project.present?
        errors << "Invalid Identifier..!"
      end
    else
      errors <<  "Dept code or Name is required."
    end
    if errors.present?
      render_json_errors(errors)
    end
  end

  def validate_priority_and_date
    if params[:priority].present?
      @priority = IssuePriority.find_by_name(params[:priority])
      unless @priority.present?
         render :json => "priority not found..!"
      end
    end

    if params[:validTill].present?
      begin
      @validity = params[:validTill].to_date
      if @validity.present?
        unless @validity > Date.today
          render :json => "validTill date should be greater than today"
        end
      end
      rescue
        render :json => "validTill is not a date..!"
      end
    end
  end

  def render_json_errors(errors)
    render :json => {:errors => errors}, :status => 500,:errors=>errors, :layout => nil
  end

  def render_json_ok(issue)
    render_json_head(issue,"ok")
  end


  def render_json_head(issue,status)
    render :json => {:ticket_id=>issue.id, :status_name => issue.status.name, :updated_on => issue.updated_on}, :status => 200, :layout => nil
  end


end
