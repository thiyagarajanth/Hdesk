require 'csv'
require 'iconv'
require 'rubygems'
require 'pdf-reader'
class ApprovalDefinitionsController < ApplicationController
  
  accept_api_auth :create, :update, :destroy

  skip_before_filter :authorize, :check_external_users, :only => [:agreement, :agreement_view]

  unloadable
  include CategoryApprovalConfigsHelper
  
  def new
    @ticket = TicketApproval.new
  end

  def create
    interrupt_length =  params[:interruption]
    approval_def = params[:category_approval_configs]
    tags = approval_def[:values].to_a
    @parent_id = nil
    saved = false
    tags.each_with_index do |tag,i|
      if !tag.empty?
        @ticket = TicketTag.find_or_initialize_by_name_and_project_id_and_category_id(tag,approval_def[:project_id],approval_def[:project_category_id])
        @ticket = TicketTag.new(:name => tag, :project_id => approval_def[:project_id], :category_id => approval_def[:project_category_id]) if !@parent_id.nil? && @ticket.parent_id != @parent_id
        @ticket.parent_id = @parent_id unless @ticket.id.present?
        @ticket.root = i + 1
        if params[:category_approval_configs][:have_agreement] == "on"
          @ticket.have_agreement = true
          @ticket.agreement_code = params[:agreement_code]
          @ticket.agreement_name = params[:agreement_name]
        else 
          @ticket.have_agreement = false
          @ticket.agreement_code = ''
          @ticket.agreement_name = ''
        end
        @ticket.save
        p @ticket.errors
        @parent_id = @ticket.id
        saved = true
      end
    end
    latest_tag = TicketTag.where(:name =>tags.last,:project_id => approval_def[:project_id],:category_id => approval_def[:project_category_id]).last
    if latest_tag.present? && approval_def[:validity].present?
      latest_tag.update_attributes(:validity => approval_def[:validity].empty? ? 0 : approval_def[:validity] )
    end
    levels = approval_def[:levels]
    
    levels.each do |k,v|
      if v!='0'
        key = ApprovalRole.where(:project_id => approval_def[:project_id], :name => k).last
        if latest_tag.present?
          approval = TicketApproval.find_or_initialize_by_ticket_tag_id_and_approval_role_id(latest_tag.id,key.id)
          approval.save
        end
        if interrupt_length.present? && interrupt_length[:role].present? && interrupt_length[:role].include?(key.id.to_s)
          pos = interrupt_length[:role].index(key.id.to_s)
          t_approval = TicketApproval.new(:ticket_tag_id =>latest_tag.id)
          t_approval.can_override = interrupt_length[:type][pos] == 'override'
          t_approval.user_id = interrupt_length[:user][pos]
          t_approval.ref_id = approval.id
          t_approval.save
        end
        saved = true
      end
    end if levels.present?
    if saved
      flash[:notice] = 'Successful created.'
      redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system')
    else
      flash[:error] = @ticket.errors.full_messages.to_sentence
      redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system', :project_category_id => @ticket.category_id )
    end
  end

  def edit
    tag = TicketTag.find(params[:id])
    if tag.ticket_approvals.present?
      ticket_id  = tag.ticket_approvals.first.id
    else
      ticket_id = nil
    end
    redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system', :project_category_id => tag.category_id, :ticket_tag_id => tag.id, :ticket_id => ticket_id, :approval => tag.category.need_approval, :validity => tag.validity )
  end

  def update
    interrupt_length =  params[:interruption]
    approval_def = params[:category_approval_configs]
    
    tag = TicketTag.find(params[:ticket_tag_id])

    if params[:category_approval_configs][:have_agreement] == "on"
      tag.have_agreement = true
      tag.agreement_code = params[:agreement_code]
      tag.agreement_name = params[:agreement_name]
    else 
      tag.have_agreement = false
      tag.agreement_code = ''
      tag.agreement_name = ''
    end
    tag.update_attributes(:validity => approval_def[:validity].empty? ? 0 : approval_def[:validity] )
    @tag = tag.id
    if approval_def[:values].present?
      approval_def[:values].each_with_index do |val, i|
        tag = TicketTag.find(approval_def[:tag_ids].reverse[i]) rescue nil
        tag = TicketTag.new(:project_id => approval_def[:project_id],:category_id => approval_def[:project_category_id]) if !tag.present?
        tag.name = val
        if !tag.id.present? && tag.parent_id.nil?
          tag.parent_id = @tag.id
          @tag.update_attributes(:root => @tag.root.to_i + 1)
        end
        tag.save

        if !val.present?
          parent = tag.parent
          parent.update_attributes(:root => parent.root - 1 )
          tag.delete
        end
        @tag = tag if tag.id.present?
      end 
    else
      tag = TicketTag.find(params[:ticket_tag_id])
    end
# raise
    # tag = TicketTag.find(params[:ticket_tag_id])
    levels = approval_def[:levels]
    saved = false
    levels.each do |k,v|
      if v!='0'
        key = ApprovalRole.find_by_project_id_and_name(approval_def[:project_id], k)
        approval = TicketApproval.find_or_initialize_by_ticket_tag_id_and_approval_role_id(tag.id,key.id)
        approval.save
        i_ids = TicketApproval.where("user_id IS NOT NULL").where(:ticket_tag_id => tag.id)
        if interrupt_length.present? && interrupt_length[:role].present? && interrupt_length[:role].include?(key.id.to_s)
          pos = interrupt_length[:role].index(key.id.to_s)
          i_app = TicketApproval.find_or_initialize_by_ref_id_and_ticket_tag_id(approval.id,tag.id)
          i_app.can_override = interrupt_length[:type][pos] == 'override'
          i_app.user_id = interrupt_length[:user][pos]
          i_app.save
        else
          i_app = TicketApproval.find_or_initialize_by_ref_id_and_ticket_tag_id(approval.id,tag.id)
          i_app.delete if i_app.present? && !i_app.user_id.nil?
        end
        saved = true
      elsif v=='0'
        key = ApprovalRole.where(:project_id => approval_def[:project_id], :name => k).last
        info = tag.ticket_approvals.find_by_approval_role_id(key) rescue nil
        if !info.nil?
          info.child.delete if info.child.present?
          info.destroy 
        end
      end
    end if levels.present?
    if saved
      flash[:notice] = 'Successful updated.'
      redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system', :page => params[:page])
    else
     if @ticket.present? && @ticket.errors.present?
        flash[:error] = @ticket.errors.full_messages.to_sentence
      end
      redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system', :page => params[:page])
    end
  end

  def index
    @tickets = TicketTag.all
  end

  def destroy
    tag = TicketTag.find(params[:id])
    issues = tag.issues
    can_delete = true
    tag_count = 0
    if issues.present?
      state = IssueStatus.find_by_name('Waiting for approval')
      can_delete = !issues.map(&:status_id).include?(state.id)      
    end
    if tag.parent.present?
      tag_count = TicketTag.where(:parent_id => tag.parent.id).count
    end
    if can_delete 
      tag.destroy
      tag.parent.destroy if tag.parent.present? && tag_count == 1
      flash[:notice] = 'Successful deleted.'
    else
      flash[:error] = 'Sorry!, This record was associated with some Tickets.'
    end
    redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system')
  end

  def add_ticket_list
    category = ProjectCategory.find(params[:project_category_id])
    tickets = category.category_approval_configs.collect{|rec|[rec.value1, rec.id]}
    render :json => {ticket: tickets }
  end

  def set_tracker
    tracker = Tracker.find(params[:issue][:tracker_id])
    projects = tracker.core_fields.include?('project_ids')
    appr_sys = tracker.core_fields.include?('approval_workflow')
    cat_app = false
    if params[:tickets][:category_id].present?
      cat = ProjectCategory.find(params[:tickets][:category_id])
      cat_app = cat.need_approval
    end
    render :json => {project:  projects, approval: appr_sys, cat_approval: cat_app }
  end

  def associate_tickets
    project = Project.find_by_identifier(params[:project_id])
    ApprovalDefinition.arel_table
    tickets = TicketTag.where(:project_id => project.id, :category_id => params[:category_id])
    conditions = ['name like ?', "%#{params[:term]}%"]
    final_collection = tickets.where(conditions)
    task = []
    final_collection.each do |rec| 
      if rec.parent != nil && rec.child != nil
        if rec.child.present?
          id = rec.child.id
        else
          id = rec.id
        end
        root2 = rec.parent.present? ? rec.parent.name : ''
        root1 = rec.name
        root = rec.child.present? ? rec.child.name : ''
      elsif rec.parent != nil
        id = rec.id
        root = rec.name
        root1 = rec.parent.present? ? rec.parent.name : ''
        root2 = rec.parent.present? ? (rec.parent.parent.present? ? rec.parent.parent.name : '') : ''
      elsif rec.child != nil
        id = rec.child.id
        id = rec.child.child.id if rec.child.child.present?
        root1 = rec.child.present? ? rec.child.name : ''
        root = rec.child.present? ? (rec.child.child.present? ? rec.child.child.name : '') : ''
        root2 = rec.name
      else
        id = rec.id
        root = rec.name
        root1=''
         root2 = ''
      end
      task << {:id => id, :name => root2 +' '+ root1+' ' + root}
    end
    task.uniq! {|e| e[:id] }
    requests = task.map { |e| { id: e[:id], text: e[:name]}}
    render :json => {result: requests }
  end

  def respond_ticket
    @issue = Issue.find(params[:issue_id])
    approval = @issue.ticket_tag.ticket_approvals
    
    if params[:due_date].present? && @issue.due_date.present? && @issue.due_date.strftime("%F") != params[:due_date]
      journal = Journal.create(journalized_id: @issue.id, journalized_type: 'Issue', user_id: User.current.id,notes: ' .' )
      JournalDetail.create(journal_id: journal.id, property: "attr", prop_key: "due_date", old_value: @issue.due_date, value: params[:due_date])
      @issue.due_date = params[:due_date]
    end
    if params[:clarification] == 'true'
      result = clarification_ticket(@issue, approval, params)
    elsif params[:status] == 'false'
      result = reject_ticket(@issue, approval, params)
    elsif params[:status] == 'true'
      if params[:ticket_author]=='true'
        result = @issue.ticket_need_approval(approval, params)
      else
        result =  approve_ticket(@issue, approval, params)
      end
    end

    @issue.save
    # Mailer.deliver_issue_edit(@issue.journals.last)
    render :json => {result: result }
  end
  
 def group_users
    group = Group.find_by_lastname('Everyone')
    if group.present?
    users = group.users.order('firstname').collect{|rec| [rec.id,rec.name] }
    else
      users = []
    end
    render :json => {users: users }
  end

  def update_interruption
    interruptions = TicketTag.find(params[:tickets]).ticket_approvals
    data = []
    interruptions.each do |rec|
      type = rec.can_override == true ? 'override' : 'intermediate'
      data << [rec.parent.approval_role.name, type,rec.user_id, rec.parent.approval_role_id] if rec.user_id.present?
    end
    render :json => {data: data}
  end

  def get_tags
  
    project = Project.find_by_identifier(params[:project_id])
    tags = TicketTag.where(:project_id => project.id, :category_id => params[:category_id])
    if params[:position] == '1'
      tags = tags.where(:root => 1).where("name like ?", "%#{params[:query]}%") 
    else
      tags = tags.where(:root => 2).where("name like ?", "%#{params[:query]}%") 
    end
    data = []
    tags.each do |tag|
        data << tag.name
    end
    render :json => {data: data}
  end

  def filterTag
    data = {}
    ids = (params[:ids].count != 1 || params[:ids].class == String) ? params[:ids] : params[:ids].join('')
    tag = TicketTag.where(:id => ids.split(','))
    data = tag.map{|x| { id: x.id, text: x.name}} if tag.present?

    render :json => {data: data}
  end

  def tag_duedate
    tag = TicketTag.find_by_id(params[:tag])
    if tag
      data = tag.validity
      render :json => {data: data}
    else
      render :json => {data: 0}
    end

  end

  def manage_team_members

    project = Project.find_by_identifier(params[:project_id])
    params[:user_id].each_with_index do |user, i|
      profile = TeamProfile.find_by_user_id_and_project_id(user,project.id) rescue nil
      profile = profile.present? ? profile : TeamProfile.new(:user_id => user)
      profile.project_id = project.id
      profile.designation=params[:designation][i]
      profile.priority=params[:priority][i]
      profile.display=params[:display].present? ? params[:display].include?(user) : false
      profile.name = params[:name][i]
      profile.save if profile.user.active?
    end
    flash[:notice] = 'Users Successfully  Updated.'
    redirect_to settings_project_path(params[:project_id], :tab => 'team_members')
  end

  def get_assignable_users
    @project = Issue.find(params[:project_id]).project
    users = @project.assignable_users
    requests = users.map { |e|  [e[:id],  (e[:firstname] +' '+e[:lastname])] }
    render :json => {result: requests }
  end


  def export_tags
         @parent_tags=[]
          @child_tags=[]
          parent_tags=[]
          child_tags=[]
          if !params[:columns].present? && params[:tags].present?
                tags = params[:tags].split(',')
                tags.each do |each_tag|
                find_tag = TicketTag.find(each_tag)
                if find_tag.present?
                  if find_tag.parent_id.nil?
                 parent_tags << find_tag.id
                else
                 child_tags << find_tag.id
                end
              end
              end
              if parent_tags.present?
                  sql_for_export_values = "select pc.cat_name as category,IF(LENGTH(ttc.name), CONCAT(tt.name, '>', ttc.name), tt.name) as cat_values,tt.validity as max_validity,1 as  self from ticket_tags tt
              join project_categories pc on pc.id=tt.category_id
              left join ticket_tags ttc on ttc.parent_id=tt.id
              where tt.parent_id is null "

                 if params[:project_id].present?
                        sql_for_export_values = sql_for_export_values + "" + " and pc.project_id='#{Project.find_by_identifier(params[:project_id]).id}' "
                  end
                  if !params[:columns].present?

                    if params[:category_id].present?
                      sql_for_export_values = sql_for_export_values + "" + " and pc.id=#{params[:category_id].to_i} "
                    end
                    if params[:tags].present?
                      sql_for_export_values = sql_for_export_values + "" + " and tt.id in (#{parent_tags.present? && parent_tags.count > 1 ? parent_tags.join('>') : parent_tags.first}) "
                    end

                     @parent_tags = ProjectCategory.find_by_sql(sql_for_export_values)
              end
              end

              if child_tags.present?

                  sql_for_export_values = "select pc.cat_name as category,IF(LENGTH(ttc.name), CONCAT(tt.name, '>', ttc.name), tt.name) as cat_values,tt.validity as max_validity,1 as  self from ticket_tags tt
              join project_categories pc on pc.id=tt.category_id
              left join ticket_tags ttc on ttc.parent_id=tt.id
              where ttc.id is not null "

                 if params[:project_id].present?
                        sql_for_export_values = sql_for_export_values + "" + " and pc.project_id='#{Project.find_by_identifier(params[:project_id]).id}' "
                  end
                  if !params[:columns].present?

                    if params[:category_id].present?
                      sql_for_export_values = sql_for_export_values + "" + " and pc.id=#{params[:category_id].to_i} "
                    end
                    if params[:tags].present?
                      sql_for_export_values = sql_for_export_values + "" + " and ttc.id in (#{child_tags.present? && child_tags.count > 1 ? child_tags.join('>') : child_tags.first}) "
                    end
                     @child_tags = ProjectCategory.find_by_sql(sql_for_export_values)

                   end

              end

              @tags = @parent_tags+@child_tags

              else

              sql_for_export_values = "select pc.cat_name as category,IF(LENGTH(ttc.name), CONCAT(tt.name, '>', ttc.name), tt.name) as cat_values,tt.validity as max_validity,1 as  self from ticket_tags tt
              join project_categories pc on pc.id=tt.category_id
              left join ticket_tags ttc on ttc.parent_id=tt.id
              where pc.cat_name is not null "

                 if params[:project_id].present?
                        sql_for_export_values = sql_for_export_values + "" + " and pc.project_id='#{Project.find_by_identifier(params[:project_id]).id}' "
                  end

              if params[:category_id].present? && !params[:columns].present?
                      sql_for_export_values = sql_for_export_values + "" + " and pc.id=#{params[:category_id].to_i} "
                    end
                    order_query = "  order by pc.cat_name,cat_values"
                    sql_for_export_values = sql_for_export_values + order_query
                     @tags = ProjectCategory.find_by_sql(sql_for_export_values)

                end

                 respond_to do |format|
                    # format.html
                    format.csv { send_data TicketApproval.tags_export(@tags,Project.find_by_identifier(params[:project_id]).id) ,filename: "#{params[:project_id]}-category-list_#{Date.today}.csv" }
                    # format.xls # { send_data @products.to_csv(col_sep: "\t") }
                  end
                  # format.csv  { send_data(query_to_csv(@issues, @query, params), :type => 'text/csv; header=present', :filename => 'issues.csv') }

  end



  def import_categories

    file = params[:file].path if params[:file].is_a?(File)
    @messages = Array.new
    # Delete existing iip to ensure there can't be two iips for a user
    # ImportInProgress.delete_all(["user_id = ?",User.current.id])
    @original_filename = params[:file].original_filename if params[:file].present?
    file_extension =  File.extname(@original_filename) if @original_filename.present?
    if params[:file].present? && file_extension == ".csv"
      @row_count=[]
      @success_count=[]

      CSV.foreach(params[:file].path, headers: true) do |row|
        @row_count << true
        product_hash = row.to_hash
        @project = Project.find(params[:project_id])
        if product_hash["category"].present?
          #
          find_category = ProjectCategory.find_by_cat_name_and_project_id(product_hash["category"],@project.id)
          if find_category.present?

            cat_tags = product_hash["cat_values"].split(">")

            if cat_tags.count.to_i > 1
              init_ticket_tag =  TicketTag.find_or_initialize_by_project_id_and_name(@project.id,cat_tags.first.to_s.strip)
              init_ticket_tag.root=1
              init_ticket_tag.category_id = find_category.id
              # init_ticket_tag.save
              if init_ticket_tag.save

                init_ticket_tag_child =  TicketTag.find_or_initialize_by_project_id_and_name(@project.id,cat_tags.last.to_s.strip)
                init_ticket_tag_child.root=2
                if init_ticket_tag_child.id.blank?
                  @new_rec=true
                else
                  @new_rec=false
                end
                init_ticket_tag_child.category_id = find_category.id
                init_ticket_tag_child.parent_id=init_ticket_tag.id
                # @success_count << true
                if @new_rec==true && init_ticket_tag_child.save
                  @success_count << true
                  product_hash.each_with_index do |each_hash,index|
                    if index > 3
                      find_approval_role = ApprovalRole.find_by_name(each_hash.first)
                      if find_approval_role.present?
                        if each_hash.last.to_s == "true"
                          ticket_approval = TicketApproval.find_or_initialize_by_ticket_tag_id_and_approval_role_id(init_ticket_tag_child.id,find_approval_role.id)
                          ticket_approval.save
                        end
                      else
                        @messages << "Approval Role Not found for #{find_approval_role.name}."
                      end
                    end
                  end
                else
                  @messages << "Reason: Can not import value #{init_ticket_tag.name} Already Exist."
                end

              else

                # init_ticket_tag_child.errors.full_messages.each do |each_error|
                #  @messages << each_error
                # end

              end

            else

              init_ticket_tag =  TicketTag.find_or_initialize_by_project_id_and_name(@project.id,cat_tags.first.to_s.strip)
              init_ticket_tag.root=1
              init_ticket_tag.category_id = find_category.id
              if init_ticket_tag.id.blank?
                @new_rec=true
              else
                @new_rec=false
              end
              # init_ticket_tag.save
              if @new_rec==true && init_ticket_tag.save
                @success_count << true
                product_hash.each_with_index do |each_hash,index|

                  if index > 3
                    find_approval_role = ApprovalRole.find_by_name(each_hash.first)
                    if find_approval_role.present?
                      if each_hash.last.to_s == "true"
                        ticket_approval = TicketApproval.find_or_initialize_by_ticket_tag_id_and_approval_role_id(init_ticket_tag.id,find_approval_role.id)
                        ticket_approval.save
                      end
                    else
                      @messages << "Reason: #{find_approval_role.name} Approval Role Not found."
                    end

                  end
                end
              else
                # init_ticket_tag.errors.full_messages.each do |each_error|
                #  @messages << "Reason: #{each_error} for #{init_ticket_tag.name}"
                #  end
                @messages << "Reason: Can not import value #{init_ticket_tag.name} Already Exist."

              end
            end
            # :name=>cat_tags.first,:category_id=>find_category.id,:project_id=@project.id,:root=>1
          else
            @messages << "Reason: Category Not found for #{product_hash["category"]} "

          end

        end

      end # end C
      @messages.unshift("Imported Total:#{@row_count.count} Success:#{@success_count.count},Failed : #{@row_count.count - @success_count.count}")

    else
      @messages << "Please attach CSV format file"
    end

    if request.xhr?

      if @messages.present? && @messages.count > 1

        @errors=""
        # @messages = ["shiva","reddy"]
        @messages.each do |s|
          @errors += ("<li>"+s+"</li>")
        end
        render :json => {

            :errors=> @errors
        }
      else
        render :json => {
            :success=> "Success full imported..!"
        }

      end
    end
  end

  def agreement
    key = Redmine::Configuration['iServ_api_key']
    base_url = Redmine::Configuration['iServ_url']
    url = base_url+"/services/message/sync"
    code_name = []
    param = {    :serviceId=> "getAgreementByDepartment", :params=> {:departmentCode => params[:dept]}.to_json}.to_json
    begin
      code_name = RestClient::Request.execute(:method => :post,:url => url,
      :payload =>{    :serviceId=> "getAgreementByDepartment", :params=> {:departmentCode => params[:dept]}.to_json}.to_json  ,:headers => {'Accept' => :json, 'Content-Type' => 'application/json','Auth-key' => key },:verify_ssl => false)
      res =  JSON.parse(code_name)
      render :json => {values: JSON.parse(res['result'])}
    rescue RestClient::Exception => e
      puts e.http_body
      render :json => {values: []}
    end
    
  end

  def agreement_view
    agreement_code =params[:code]
    key = Redmine::Configuration['iServ_api_key']
    base_url = Redmine::Configuration['iServ_url']
    require 'json'
    require 'rest_client'
    #url = base_url+"/services/message/sync"
    url = base_url+"/services/employees/agreements/"+agreement_code

    begin
      response = RestClient::Request.execute(:method => :get,:url => url, :headers => {'Auth-key' => key },:verify_ssl => false)
    rescue RestClient::Exception => e
      response = ["result" => '']
      puts e.http_body
    end
    render :json => {result: response}
  end
  
  def accept_agreement
      agree_status = params[:agree_status]
      user = User.find(User.current.id)
      user_name = user.firstname
      @issue = Issue.find(params[:issue_id])
      approval = @issue.ticket_tag.ticket_approvals
      old_status = @issue.status_id
      st1 = "I Agree".casecmp(agree_status)
      if (st1 == 0 || ('i do not agree'.casecmp(agree_status)))
        issue_ticket_tag = @issue.issue_ticket_tag
        issue_ticket_tag.accept_agreement = true
        issue_ticket_tag.save
        if @issue.ticket_tag.have_agreement == true
          o_status = IssueStatus.find_by_name('Open')
          r_status = IssueStatus.find_by_name('Rejected')
          if st1==0 
            status =  o_status
            note = "#{user_name} has accepted #{@issue.ticket_tag.agreement_name}"
          else
            status = r_status
            note = "The ticket has been rejected since you have not accepted the license agreement"
          end
          default_assignee =  DefaultAssigneeSetup.find_by_project_id_and_tracker_id(@issue.project_id, @issue.tracker_id)
          @issue.status_id = status.id
          @issue.assigned_to_id = default_assignee.present? ? default_assignee.default_assignee_to : DefaultAssigneeSetup.new

          saved = @issue.save(:validate => false)
          if saved
                 helper = Object.new.extend(CategoryApprovalConfigsHelper)
                 helper.push_notification(@issue)
                 true
          end
          journal = Journal.create(journalized_id: params[:issue_id], journalized_type: 'Issue', user_id: User.current.id,notes: note )
          JournalDetail.create(journal_id: journal.id, property: "attr", prop_key: "status_id", old_value: old_status, value: status.id)
        end
        default_assignee = default_assignee.present? ? default_assignee : DefaultAssigneeSetup.new
      else
          p 'present in else '
      end
      have_agreement = @issue.ticket_tag.have_agreement rescue ''
      accept_agreement = @issue.issue_ticket_tag.accept_agreement rescue ''
      @issue.issue_ticket_tag

  end
  # def agreement
    # code_name = [["02dfa","laptop"],["25ffv","RAM"],["7e3vcv","Mobile"],["5d4gg","Accessrights"]]
    # render :json => {values: code_name }
  # end
  # def respond_ticket
  #   @issue = Issue.find(params[:issue_id])
  #   approval = @issue.ticket_tag.ticket_approvals
    
  #   if params[:due_date].present? && @issue.due_date.present? && @issue.due_date.strftime("%F") != params[:due_date]
  #     journal = Journal.create(journalized_id: @issue.id, journalized_type: 'Issue', user_id: User.current.id,notes: ' .' )
  #     JournalDetail.create(journal_id: journal.id, property: "attr", prop_key: "due_date", old_value: @issue.due_date, value: params[:due_date])
  #     @issue.due_date = params[:due_date]
  #   end
  #   if params[:clarification] == 'true'
  #     p '=========== 1 =============='
  #     result = clarification_ticket(@issue, approval, params)
  #   elsif params[:status] == 'false'
  #     p '=========== 2 =============='
  #     result = reject_ticket(@issue, approval, params)
  #     p '=========== 3 =============='
  #   elsif params[:status] == 'true'
  #     if params[:ticket_author]=='true'
  #       result = @issue.ticket_need_approval(approval)
  #     else
  #       result =  approve_ticket(@issue, approval, params)
  #     end
  #   end

  #   @issue.save
  #   # Mailer.deliver_issue_edit(@issue.journals.last)
  #   render :json => {result: result }
  # end

end
