# require 'application_helper'
require 'forwardable'
require 'cgi'
module CategoryApprovalConfigsHelper
  include Redmine::WikiFormatting::Macros::Definitions
  include Redmine::I18n
  include GravatarHelper::PublicMethods
  include Redmine::Pagination::Helper

  extend Forwardable
  def_delegators :wiki_helper, :wikitoolbar_for, :heads_for_wiki_formatter
  include ApplicationHelper
# include ApplicationHelper
  def reject_ticket(issue, approvals, params)
    current_user_id = params[:user_id].present? ? params[:user_id] : User.current.id
    # journal = Journal.create(journalized_id: params[:issue_id], journalized_type: 'Issue', user_id: current_user_id,notes: params[:comment] )
    issue.init_journal(User.find(current_user_id), params[:comment])
    last_info = issue.ticket_approval_flows.last
    last_approval = last_info.ticket_approval
    TicketApprovalFlow.create(:issue_id => issue.id, :ticket_approval_id => last_approval.id, :user_id => current_user_id, :status => 'Rejected', :notes => params[:comment] )
    issue.assigned_to_id = issue.author_id
    old_status = issue.status_id
    status = IssueStatus.find_by_name('Rejected')
    issue.status_id = status.id
    issue.save(validate: false)
    # JournalDetail.create(journal_id: journal.id, property: "attr", prop_key: "status_id", old_value: old_status, value: status.id)
    return true
  end

  def clarification_ticket(issue, approvals, params)
    current_user_id = params[:user_id].present? ? params[:user_id] : User.current.id
    # journal= Journal.create(journalized_id: params[:issue_id], journalized_type: 'Issue', user_id: current_user_id ,notes: params[:comment] )
    issue.init_journal(User.find(current_user_id), params[:comment])
    flows =  issue.ticket_approval_flows
    flow =  flows.where("status='approved'")
    if flow.present?
      us = flow.where(:user_id => current_user_id)
      if us.present?
        as = flow.where('id < ?', us.first.id).last
        if as.nil?
          is_multilevel_approval = flows.where(:user_id => current_user_id,:status=> "pending")
          if is_multilevel_approval.present?
            last_approval = flow.last.ticket_approval
            issue.assigned_to_id = flow.last.user_id
          else
            last_approval = us.first.ticket_approval
            issue.assigned_to_id = issue.author_id
          end

        else
          last_approval = as.ticket_approval
          issue.assigned_to_id = as.user_id
        end
      else
        last_approval = flow.last.ticket_approval
        issue.assigned_to_id = flow.last.user_id
      end
    else
      last_approval = issue.ticket_approval_flows.first.ticket_approval
      issue.assigned_to_id = issue.author_id
    end
    update_state = issue.ticket_approval_flows.where("user_id=#{current_user_id} and (status = 'pending' or status='Information required')").last
    update_state.status = 'Information required'
    update_state.notes = params[:comment]
    update_state.save
    begin
      TicketApprovalFlow.create(:issue_id => issue.id, :ticket_approval_id => last_approval.id, :user_id => issue.assigned_to_id, :status => 'Information required', :notes => params[:comment] )
    rescue
      'Cool'
    end

    status = IssueStatus.find_by_name('Need Clarification')
    old_status = issue.status_id
    issue.status_id = status.id
    issue.save(validate: false)
    #JournalDetail.create(journal_id: journal.id, property: "attr", prop_key: "status_id", old_value: old_status, value: status.id)
    return true
  end


  def approve_ticket(issue, approvals, params)
    valid = true
    current_user_id = params[:user_id].present? ? params[:user_id] : User.current.id
    comments = params[:comment].present? ? params[:comment] : 'Approved'
    assignee =  ApprovalRole.set_assignee_value(issue)
    project = issue.inia_project
    last_info = issue.ticket_approval_flows.last
    author_role = get_author_role(project, issue)
    p approval_list = approvals.where("user_id IS NULL")
    p inter_list = approvals.where("user_id IS NOT NULL")
    p '===role===='

    p approval_list
    p '=='
    p approval_list.last
    p approval_list.last.approval_role
    req_level = approval_list.last.approval_role.level
    last_approval = last_info.ticket_approval
    #=========================================================================
    p cur_level_id = get_current_user_role(issue, nil)
    p cur_level_id = get_current_user_role(issue, params[:user_id]) if params[:user_id].present?
    cur_lvl = cur_level_id
    p '---d---'
    lvl = inter_list.map{|x|x.parent.approval_role.level}

    if inter_list.present? && (lvl.min >= cur_level_id.min[0][0] && lvl.max <= cur_level_id.max[0][0])
      curmin = cur_level_id.min[0][0]
      curmax = cur_level_id.max[0][0]
      p cur_level = curmin
      cur_level_id = curmin
      p '==================rec-----'
      #p rec2 = approvals.find_by_approval_role_id(cur_level_id)
      rep = []
      inter_list.each do |l|
        resp =  TicketApprovalFlow.where(:issue_id => issue.id, :ticket_approval_id => l.id, :user_id => l.user_id).map(&:status).include?('Approved')
        if resp
          rep << resp
        else
          cur_level_id = l.parent.approval_role.level -   1
          cur_level    = cur_level_id
          break
        end
      end
      p [rep.count , inter_list.count]
       if rep.count >= inter_list.count
         cur_level = curmax
         cur_level_id = curmax
       end
      #p tpp = TicketApprovalFlow.where(:issue_id => issue.id, :ticket_approval_id => rec2.child.id).last if rec2.present? && rec2.child.present?
      p '-----came----'
      # if resp
      #   p 'called------------------'
      #   p cur_level_id = cur_lvl.max[0][0]
      #   p cur_level = cur_lvl.max[0][0]
      # end
    else
      p '===============yes=====co==='
      p cur_level = cur_level_id.max[0][0]
      p cur_level_id = cur_level_id.max[0][0]
    end


    # if inter_list.present?
    #   cur_level_id = get_current_user_role(issue, nil).min[0]
    #   cur_level_id = get_current_user_role(issue, params[:user_id]).min[0] if params[:user_id].present?
    # else
    #   cur_level_id = get_current_user_role(issue, nil).max[0]
    #   cur_level_id = get_current_user_role(issue, params[:user_id]).max[0] if params[:user_id].present?
    # end
    # cur_level = cur_level_id[0]
    #====================================================================



    p '=========current levbel=========='
    p cur_level
    p last_approval
    if last_approval.present? && last_approval.user_id.present?
      p '=========== 2 ============thiygu  ====='
      #TicketApprovalFlow.create(:issue_id => issue.id, :ticket_approval_id => last_approval.id, :user_id => User.current.id, :status => 'Approved', :notes => params[:comment] )
      if last_approval.can_override==true
        cur_level = last_approval.parent.approval_role.level
      else
        p cur_level
        p '=========== 2 ==1==========thiygu  ====='
        c_level = last_approval.parent.approval_role.level - 1
        # us = issue.get_next_approver(c_level).first
        # p rsp =  TicketApprovalFlow.where(:issue_id => issue.id, :user_id  => us).map(&:status).include?('Approved')
        # c_level = c_level + 1 if rsp
        p last_approval.child
        p [c_level, cur_level]
        #  child_cur = approvals.find_by_approval_role_id(cur_level_id).child
        # if child_cur.present?
        #   cur_level = cur_level
        # end
        cur_level = (c_level > cur_level ? c_level : (c_level==0 ? c_level : cur_level))
      end
    else
      p '=========== 2 ====3========thiygu  ====='
      p approvals
      if approvals.present?
      p  rec12 = approvals.find_by_approval_role_id(cur_level_id[1])
      p '===== 22222===='
        if rec12.present? && rec12.child.present?
          p rec12.child
          p cur_level
          p TicketApprovalFlow.where(:issue_id => issue.id, :user_id => User.current.id).map(&:status)
          cur_approver = TicketApprovalFlow.where(:issue_id => issue.id, :user_id => User.current.id).map(&:status).include?('Approved')
         p   state = TicketApprovalFlow.where(:issue_id => issue.id, :user_id => rec12.child.user_id).last
            cur_level = cur_level - 1 if !cur_approver && state.present? && state.status != 'Approved'
            cur_level = cur_level - 1  if !cur_approver && !state.present?
        end
      end
      #TicketApprovalFlow.create(:issue_id => issue.id, :ticket_approval_id => last_approval.id, :user_id => User.current.id, :status => 'Approved', :notes => params[:comment] )
p '======oks===='
     p cur_level = cur_level.present? ? cur_level : 0
    end
    update_state = issue.ticket_approval_flows.where("user_id=#{current_user_id} and (status = 'pending' or status='Information required')").last
    if update_state.present?
      update_state.status = 'Approved'
      update_state.notes = params[:comment]
      update_state.save
    end
    cur_def = nil
    approval_list.each_with_index do |app,i|
      if app.approval_role.level == cur_level + 1
        cur_def = app
        break
      end
    end
    next_user_id = nil
    if (cur_level >= req_level && cur_level <= author_role) || (cur_level<author_role && last_approval.user_id.present?)
      l_level = last_approval.parent.approval_role.level
      l_app = last_approval
      ids = issue.ticket_approval_flows.where("status !='Information required'").collect{|rec|rec.ticket_approval_id}
      i = 0
      l_rec = nil
      set = true

      until (l_level > author_role) #&& set
        p '============ 2 =========='
        set = false
        level = ApprovalRole.find_by_level(l_level )    
        break if !level.present?
        p '========3 ==========='
        appro = approvals.where(:approval_role_id => level.id).first
        if appro.present? && appro.child.present? && !ids.include?(appro.child.id)
          p '=========== 4 ========='
          l_rec = appro.child
          p next_user_id = appro.child.user_id
          # set = true
          break
        end

        l_level = l_level + 1
        break if l_level > author_role && next_user_id != issue.author_id # && set
      end
    end
    step1 = !cur_def.present? || (l_level.present? && l_level > req_level)
    if (!next_user_id.present? && step1 && issue.ticket_tag.have_agreement == true)
      comments = comments + ", Please accpet the agreement for further action. "
    end
    issue.init_journal(User.find(current_user_id), comments)
    old_status = IssueStatus.find_by_name('waiting for approval')

     #raise

    if !next_user_id.present?
      if step1 #|| req_level <= author_role
        if issue.ticket_tag.have_agreement == true
           status = check_agreement(issue)
           valid = true
           #comments = comments + ", Please accpet the agreement for further action. "
        else   
          if issue.project.enabled_modules.map(&:name).include?('redmine_issue_sla')
            status = IssueStatus.find_by_name('open')
            SlaTime.create(:issue_id => issue.id, :issue_sla_status_id => status.id,:user_id => issue.assigned_to_id,  :old_status_id => old_status.id , :pre_status_duration => 0 )
          end
        p next_user_id = assignee
        valid = true
        end
      else
        p '=========== now ============ 3 ======'
        status = IssueStatus.find_by_name('waiting for approval')
        tag = issue.ticket_tag
        p nxt_level = cur_level + 1
        nxt_role_id = ApprovalRole.find_by_sql("select id from approval_roles where level=#{nxt_level} and project_id=#{issue.project_id}").map(&:id).first
        info = TicketApproval.find_by_sql("select * from ticket_approvals as a, approval_roles as b,ticket_tags as c where a.approval_role_id = (#{nxt_role_id}) and a.ticket_tag_id = c.id and a.ticket_tag_id = #{tag.id} order by b.level").first
        if last_approval.id == cur_def.id || cur_def.child.nil? || (last_approval.user_id.present? && last_approval.can_override==false)
          p '==============76'
          next_user_id = issue.get_next_approver(info.approval_role.level).first
         # TicketApprovalFlow.create(:issue_id => issue.id, :ticket_approval_id => cur_def.id, :user_id => next_user_id, :status => 'pending', :notes => params[:comment] )
          valid = false if !next_user_id.present?
          taf_ticket_apprival_id = cur_def.id
          taf_user_id = next_user_id
        else
          p '===============34 ======'
          next_user_id = cur_def.child.user_id
          taf_ticket_apprival_id = cur_def.child.id
          taf_user_id = cur_def.child.user_id          
          #TicketApprovalFlow.create(:issue_id => issue.id, :ticket_approval_id => cur_def.child.id, :user_id => cur_def.child.user_id, :status => 'pending', :notes => params[:comment] )
        end
        SlaTime.create(:issue_id => issue.id, :issue_sla_status_id => status.id,:user_id => issue.assigned_to_id,  :old_status_id => issue.status_id , :pre_status_duration => 0 )
      end
    else
      status = IssueStatus.find_by_name('waiting for approval')
      taf_ticket_apprival_id = l_rec.id
      taf_user_id = next_user_id
      #TicketApprovalFlow.create(:issue_id => issue.id, :ticket_approval_id => l_rec.id, :user_id => next_user_id, :status => 'pending', :notes => params[:comment] )
    end
    p '=====================below======='
    p [l_level, author_role, next_user_id, cur_level, cur_def]
    p '===============================above============='
      # raise
      if valid

        # TicketApprovalFlow.find_by_issue_id_and_user_id(issue.id, User.current.id).update_attributes(:status => 'approved')
        if next_user_id.present?
          p 'present in next 214'
        p issue.assigned_to_id = next_user_id
        else
          p 'prsent in next 217'
          issue.assigned_to_id = issue.author_id
        end

        issue.status_id = status.id
        issue.save(:validate => false)
        TicketApprovalFlow.create(:issue_id => issue.id, :ticket_approval_id => taf_ticket_apprival_id, :user_id => taf_user_id, :status => 'pending', :notes => params[:comment] )
        TicketApprovalFlow.find_or_initialize_by_issue_id_and_user_id(issue.id, current_user_id).update_attributes(:status => 'Approved')
        if issue.status.name === "Waiting for approval"
          push_notification(issue)
        end
        true
      else
        false
      end
  end

  def check_agreement(issue)
    p 'xchecllllllllllllllllllll'
    status = IssueStatus.find_or_initialize_by_name('Accept Agreement')
    status.save
    p status
    next_user_id = issue.author_id
    issue.assigned_to_id = next_user_id
    issue.status_id = status.id
    issue.save(:validate=>false)
    push_notification(issue)
    return status
    
  end

  def get_current_user_role(issue, user_id)
    level = []
    user_id = user_id.present? ? user_id : User.current.id
    # roles = issue.inia_project.approval_role_users.where(:user_id => user_id, :project_id => issue.project_id)
    roles = issue.inia_project.approval_role_users.where( :project_id => issue.project_id)
    # roles.each{|rec| level << rec.approval_role.level}
    roles.each{|rec| level << [rec.approval_role.level,rec.approval_role.id ] if rec.approval_role.present? && (rec.user_id rescue nil)== user_id }.compact
    # level.present? ? level.each_with_index.max[0] : 0
    level.present? ? level.each_with_index : [[0,0]]
  end

  def get_author_role(project, issue)
    level = []
    # roles = project.approval_role_users.where(:user_id => issue.author_id, :project_id => issue.project_id)
    p '==================rails'
    p roles = project.approval_role_users.where(:project_id => issue.project_id)
    if roles.present?
      roles.collect{|rec| level << rec.approval_role.level  if rec.approval_role.present? && (rec.user_id rescue nil) == issue.author_id }.compact
      p '======manio'
      p lel = level.max
      lel.present? ? lel : 0
    else
      0
    end
  end

  def push_notification(notify)
    key = Redmine::Configuration['iServ_api_key']
    base_url = Redmine::Configuration['iServ_url']
    require 'json'
    require 'rest_client'
    url = base_url+"/services/notifications/new-approval-ticket"
    begin
      emp_id = UserOfficialInfo.find_by_user_id(notify.assigned_to_id).employee_id rescue nil
      author_emp_id = UserOfficialInfo.find_by_user_id(notify.author_id).employee_id rescue nil
      status = IssueStatus.find_by_name('waiting for approval')
      count = Issue.where(:assigned_to_id => notify.assigned_to_id, :status_id => status.id).count
      cat_name= IssueTicketTag.find_by_issue_id(notify).project_category.cat_name rescue ''
      request = {:ticketId => notify.id,:badgeCount => count, :category => cat_name, :subject => notify.subject,
                :project => notify.project.name, :createdByEmpId => "#{author_emp_id}", :approverEmpId=> "#{emp_id}"}.to_json
      p "=========#{notify.id}=====================push notification ==================================="
      RestClient::Request.new(:method => :post, :url => url, :payload => request, :headers => {:content_type => 'json',"Auth-key" => key}, :verify_ssl => false).execute.body
    rescue => e
      Rails.logger.info '===== Exception error'
      Rails.logger.info e.message
    end
  end

  def get_user_firstname_lastname(user)
    full_name=''
    user = User.find(user.to_i)
    if user.present?
      # p "++++++++=user.employee_id+++++++"
      # p user.employee_id
      # p "++++++++++++++++=="
      full_name = "#{user.firstname + ' ' + user.lastname}" +' '+ '('+ "#{user.employee_id}" + ')' + ' '
      # full_name = "#{user.employee_id}" + ':' + user.firstname + ' ' + user.lastname

    end
    return full_name
  end

  def get_issue_status(issue)
    !issue.closed? && issue.status.name != 'Resolved'
  end


  def issue_principals_check_box_tags(access_users,name, principals)
    s = ''
    principals.each do |principal|

      s << "<label>#{ ApplicationHelper.check_box_tag name, principal.id, access_users.include?(principal.id) ? true : false , :id => nil } #{h principal}</label>\n"
    end
    s.html_safe
  end

  def auto_delegation
    users = ApprovalRoleUser.all.map{|p| [p.primary_user_id,p.secondary_user_id]}.flatten.compact.uniq
    emp_ids = UserOfficialInfo.where(:user_id => users).map(&:employee_id).uniq
    key = Redmine::Configuration['iServ_api_key']
    base_url = Redmine::Configuration['iServ_url']
    url = base_url+"/services/employees/leaveinfo"
    request = {:employeeId => emp_ids.join(','), :fromDate => Date.today.strftime("%Y-%m-%d"), :toDate => Date.today.strftime("%Y-%m-%d")}.to_json
    begin
      response = RestClient::Request.new(:method => :post, :url => url, :payload => request, :headers => {:content_type => 'json',"Auth-key" => key}, :verify_ssl => false).execute.body
    rescue => e
      response = 'failed'
    end

    leave_array = JSON.parse(response)['leaveDetails'].keys rescue []
    status = IssueStatus.find_by_name('waiting for approval')
    approvals = ApprovalRoleUser.where(:active_user=>"secondary_user")
    user_ids = UserOfficialInfo.where(:employee_id => leave_array).map(&:user_id).uniq
    approvals.each do |ar|
      if !user_ids.include?(ar.primary_user_id) && (ar.active_from.present? && ar.active_from.present?) && !(ar.active_from..ar.active_till).cover?(Date.today)
        issue_ids = ar.inia_project.issue_ticket_tags.map(&:issue_id)
        issues = Issue.where(:status_id => status.id,:id => issue_ids, :assigned_to_id => ar.secondary_user_id)
        count = issues.count
        active_from = ar.active_from
        active_till = ar.active_till
        ar.update_attributes(:active_user => 'primary_user', :active_from => nil, :active_till => nil)
        DelegationAudit.create(:inia_project_id => ar.inia_project_id, :project_id => ar.project_id, :approval_role_id =>ar.approval_role_id,
                               :primary_user_id => ar.primary_user_id, :secondary_user_id => ar.secondary_user_id, :delegated_by => User.current.id,
                               :from_date => active_from, :to_date => active_till, :status => true)
        issues.each do |issue|
          issue.init_journal(User.find_by_login('admin'), 'Auto delegation updated')
          issue.assigned_to_id = ar.primary_user_id
          issue.save
        end
        Mailer.delegation_remainder(ar.primary_user_id, ar.secondary_user_id, count, ar).deliver
      end
    end
    user_ids.each do |user|
      approvals = ApprovalRoleUser.where("primary_user_id=#{user}")
      # reassign_ticket_to_delegater(approvals, user_ids, status)
      approvals.each do |ar|
        if ar.secondary_user_id.present? && !user_ids.include?(ar.secondary_user_id)
          ar.update_attributes(:active_user => 'secondary_user', :active_from => Date.today, :active_till => Date.today)
          DelegationAudit.create(:inia_project_id => ar.inia_project_id, :project_id => ar.project_id, :approval_role_id =>ar.approval_role_id,
                                 :primary_user_id => ar.primary_user_id, :secondary_user_id => ar.secondary_user_id, :delegated_by => User.current.id,
                                 :from_date => ar.active_from, :to_date => ar.active_till, :status => true)
          issue_ids = ar.inia_project.issue_ticket_tags.map(&:issue_id)
          issues = Issue.where(:status_id => status.id,:id => issue_ids, :assigned_to_id => ar.secondary_user_id)
          count = issues.count
          issues.each do |issue|
            issue.init_journal(User.find_by_login('admin'), 'Auto delegation updated')
            issue.assigned_to_id = ar.secondary_user_id
            issue.save
          end
          Mailer.delegation_remainder(ar.secondary_user_id, ar.primary_user_id, count, ar).deliver
        end
      end
    end
    ApprovalRoleUser.where("active_user='primary_user' and DATE(active_till) < CURDATE()").update_all(:active_from=> nil, :active_till => nil)
    #---------------------Date based delegation(Manual-pre date selection)--------------
    aru_ids = ApprovalRoleUser.where("DATE(active_from) <= CURDATE() and DATE(active_till) >= CURDATE()")
    reassign_ticket_to_delegater(aru_ids, user_ids,status)

  end

  def reassign_ticket_to_delegater(approvals, user_ids,status)
    approvals.each do |ar|
      if ar.secondary_user_id.present? && !user_ids.include?(ar.secondary_user_id)
        ar.update_attributes(:active_user => 'secondary_user', :active_from => Date.today, :active_till => Date.today)
        DelegationAudit.create(:inia_project_id => ar.inia_project_id, :project_id => ar.project_id, :approval_role_id =>ar.approval_role_id,
                               :primary_user_id => ar.primary_user_id, :secondary_user_id => ar.secondary_user_id, :delegated_by => User.current.id,
                               :from_date => ar.active_from, :to_date => ar.active_till, :status => true)
        issue_ids = ar.inia_project.issue_ticket_tags.map(&:issue_id)
        issues = Issue.where(:status_id => status.id,:id => issue_ids, :assigned_to_id => ar.primary_user_id)
        count = issues.count
        issues.each do |issue|
          issue.init_journal(User.find_by_login('admin'), 'Auto delegation updated')
          issue.assigned_to_id = ar.secondary_user_id
          issue.save
        end
        Mailer.delegation_remainder(ar.secondary_user_id, ar.primary_user_id, count, ar).deliver
      end
    end
  end

  def user_inia_projects
    IniaMember.where(user_id: User.current.id).compact.collect{|s|s.inia_project if s.inia_project.present? && s.inia_project.status==1 }
  end
  def user_inia_project_ids
    IniaMember.where(user_id: User.current.id).compact.collect{|s|s.inia_project.id if s.inia_project.present? && s.inia_project.status==1 }
  end

  # due to requirement changes this methods not used
#   def ticketsassignedtome_items(id)
#     Issue.visible.open.
#         where(:assigned_to_id => ([User.current.id] + User.current.group_ids), :project_id => id).
#         limit(10).
#         includes(:status, :author, :tracker, :priority).
#         order("#{IssuePriority.table_name}.position DESC, #{Issue.table_name}.updated_on DESC").
#         all
#   end
#
#   def ticketsoverduetome_items(id)
#     ids = SlaTime.find_by_sql("select i.id, if(i.estimated_hours * 100 > sum(st.pre_status_duration),1,0) as sla from sla_times st join issues i on i.id=st.issue_id join issue_statuses si on i.status_id=si.id
# join users u on u.id=i.assigned_to_id where si.name='Assigned' and i.assigned_to_id=528 group by st.issue_id order by id desc").select{|c| c.sla == 0}.map(&:id)
#
#     Issue.visible.open.
#         where(:assigned_to_id => ([User.current.id] + User.current.group_ids), :project_id => id).
#         limit(10).
#         includes(:status, :author, :tracker, :priority).
#         order("#{IssuePriority.table_name}.position DESC, #{Issue.table_name}.updated_on DESC").
#         all
#   end

end
