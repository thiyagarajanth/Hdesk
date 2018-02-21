class WktimeController < ApplicationController
  unloadable

  include WktimeHelper

  before_filter :require_login
  before_filter :check_perm_and_redirect, :only => [:edit, :update]
  before_filter :check_editperm_redirect, :only => [:destroy]
  before_filter :check_view_redirect, :only => [:index]
  before_filter :check_log_time_redirect, :only => [:new]

  accept_api_auth :index, :edit, :update, :destroy, :deleteEntries

  helper :custom_fields


  def index
    Rails.logger.info "++index start ++++++"
    # p params
    start_time = Time.now
    retrieve_date_range
    @from = getStartDay(@from)
    @to = getEndDay(@to)
    # Paginate results
    user_id = params[:user_id]
    group_id = params[:group_id]
    @set_all_issue = user_id == '0' ? true : false
    set_user_projects
    if (!@manage_view_spenttime_projects.blank? && @manage_view_spenttime_projects.size > 0)
      @selected_project = getSelectedProject(@manage_view_spenttime_projects)
      setgroups
    end
    ids = nil
    if user_id.blank?
      ids = User.current.id.to_s
    elsif user_id.to_i == 0
      #all users
      userList=[]
      if group_id.blank?
        userList = Principal.member_of(@selected_project)
      else
        userList = getMembers
      end
      userList.each_with_index do |users,i|
        if i == 0
          ids =  users.id.to_s
        else
          ids +=',' + users.id.to_s
        end
      end
      ids = user_id if ids.nil?
    else
      ids = user_id
    end


    spField = getSpecificField()
    entityNames = getEntityNames()
    selectStr = "select v1.user_id, v1.startday as spent_on, v1." + spField
    wkSelectStr = selectStr + ", w.status "
    sqlStr = " from "
    sDay = getDateSqlString('t.spent_on')
    #Martin Dube contribution: 'start of the week' configuration
    if ActiveRecord::Base.connection.adapter_name == 'SQLServer'
      sqlStr += "(select  ROW_NUMBER() OVER (ORDER BY  " + sDay + " desc, user_id) AS rownum," + sDay + " as startday, "
      sqlStr += " t.user_id, sum(t." + spField + ") as " + spField + " ,max(t.id) as id" + " from " + entityNames[1] + " t, users u" +
          " where u.id = t.user_id and u.id in (#{ids})"
      sqlStr += " and t.spent_on between '#{@from}' and '#{@to}'" unless @from.blank? && @to.blank?
      sqlStr += " group by " + sDay + ", user_id ) as v1"
    else
      sqlStr += "(select " + sDay + " as startday, "
      sqlStr += " t.user_id, sum(t." + spField + ") as " + spField + " ,max(t.id) as id" + " from " + entityNames[1] + " t, users u" +
          " where u.id = t.user_id and u.id in (#{ids})"
      sqlStr += " and t.spent_on between '#{@from}' and '#{@to}'" unless @from.blank? && @to.blank?
      sqlStr += " group by startday, user_id order by startday desc, user_id ) as v1"
    end

    wkSqlStr = " left outer join " + entityNames[0] + " w on v1.startday = w.begin_date and v1.user_id = w.user_id"
    status = params[:status]
    if !status.blank? && status != 'all'
      wkSqlStr += " WHERE w.status = '#{status}'"
      if status == 'n'
        wkSqlStr += " OR  w.status IS NULL"
      end
    end

    findBySql(selectStr,sqlStr,wkSelectStr,wkSqlStr)
    if params[:project_id].present? && params[:user_id].to_i > 0
      @total_days=0
      params[:user_id].to_i > 0
      retrieve_date_range
      user_permissions = user_permission_list(@logtime_projects)
      @user_permission = (user_permissions.include? :l1) || (user_permissions.include? :l2)
      @prev_template = false
      @new_custom_field_values = getNewCustomField
      @startday ||= @from
      @new_entries = []
      @user ||= User.find(params[:user_id])
      @endday ||= @to
      findWkTE_l3(@startday,@endday)
      @editable = @wktime.nil? || @wktime.status == 'n' || @wktime.status == 'r'
      time_entries = TimeEntry.where(spent_on: @startday..@endday,user_id: params[:user_id],:project_id=>params[:project_id]).group('spent_on').sum('hours')
      wktime_enties = Wktime.where(:user_id => params[:user_id], :begin_date => @startday..@endday)
      l3_wktime = wktime_enties.where(:status => 'l3').map(&:begin_date)
      l2_wktime = wktime_enties.where(:status => 'l2').map(&:begin_date)
      l1_wktime = wktime_enties.where(:status => 'l1').map(&:begin_date)
      reject_wktime = wktime_enties.where(:status => 'r').map(&:begin_date)
      @new_entries << {params[:user_id] => [time_entries, l3_wktime, l2_wktime,l1_wktime,reject_wktime] }
      @total_days = (@endday - @startday).to_i
      if @new_entries.blank? && !params[:prev_template].blank?
        @prev_entries = prevTemplate(@user.id)
        if !@prev_entries.blank?
          set_project_issues(@prev_entries)
          @prev_template = true
        end
      end
      wktime_helper = Object.new.extend(WktimeHelper)
      days_count = (@startday..@endday).to_a.count
      bio_user = User.find(params[:user_id])
      if days_count == 7
        @user_hours =  wktime_helper.get_biometric_hours_per_month(bio_user,@startday,@endday,"week")
      else
        @user_hours =  wktime_helper.get_biometric_hours_per_month(bio_user,@startday,@endday,"from_to_end")
      end
    else if  params[:project_id].present? && params[:user_id].to_i == 0
           retrieve_date_range
           params[:user_id] = User.current.id
           @prev_template = false
           @new_custom_field_values = getNewCustomField
           @startday ||= @from
           @new_entries = []
           @user ||= User.find(params[:user_id])
           @endday ||= @to
           @editable = @wktime.nil? || @wktime.status == 'n' || @wktime.status == 'r'
           @project = Project.find(params[:project_id])
           # @user_hours = []
           wktime_helper = Object.new.extend(WktimeHelper)
           @total_days = (@endday - @startday).to_i
           days_count = (@startday..@endday).to_a.count

           project_users = []
           @project.users.collect do |user|
             time_entries = TimeEntry.where(spent_on: @startday..@endday,user_id: user.id,:project_id=>params[:project_id]).group('spent_on').sum('hours')
             if time_entries.present?
               project_users << user
               wktime_enties = Wktime.where(:user_id => user.id, :begin_date => @startday..@endday)
               l3_wktime = wktime_enties.where(:status => 'l3').map(&:begin_date)
               l2_wktime = wktime_enties.where(:status => 'l2').map(&:begin_date)
               l1_wktime = wktime_enties.where(:status => 'l1').map(&:begin_date)
               reject_wktime = wktime_enties.where(:status => 'r').map(&:begin_date)
               lock_wktime = wktime_enties.where(:status => 'l').map(&:begin_date)
               @new_entries << {user.id => [time_entries, l3_wktime, l2_wktime,l1_wktime,reject_wktime, lock_wktime] }
             end
           end

           #users_id_list = @project.users
           #if users_ids.count > 100
           user_group = []
           @user_hours = {}
           project_users.in_groups_of(50) {|group| user_group << group.compact }
           user_group.each do |users_ids|
             bio_wk = wktime_helper.get_biometric_hours_per_month(users_ids,@startday,@endday,"from_to_end")
             if days_count == 7
               @user_hours.merge!(bio_wk.present? ? wktime_helper.get_biometric_hours_per_month(users_ids,@startday,@endday,"week") : "")
             else
               @user_hours.merge!(bio_wk.present? ? bio_wk : {})
             end
           end

           if @new_entries.blank? && !params[:prev_template].blank?
             @prev_entries = prevTemplate(@user.id)
             if !@prev_entries.blank?
               set_project_issues(@prev_entries)
               @prev_template = true
             end
           end
         end
    end

    respond_to do |format|
      format.html {
        render :layout => !request.xhr?
      }
      format.api
    end
    p '---- change usr od ---2--'
    p user_id
    p '------'
  end

  def edit
    @user_hours=[]
    @prev_template = false
    @new_custom_field_values = getNewCustomField
    findWkTE(@startday)
    @editable = @wktime.nil? || @wktime.status == 'n' || @wktime.status == 'r'
    @entries = findEntries()
    set_project_issues(@entries)
    if @entries.blank? && !params[:prev_template].blank?
      @prev_entries = prevTemplate(@user.id)
      if !@prev_entries.blank?
        set_project_issues(@prev_entries)
        @prev_template = true
      end
    end
    wktime_helper = Object.new.extend(WktimeHelper)
    @user_hours = wktime_helper.get_biometric_hours_per_month(@user,@startday,@startday+6,"week")
    respond_to do |format|
      format.html {
        render :layout => !request.xhr?
      }
      format.api
    end
  end

  # called when save is clicked on the page
  def update
    Rails.logger.info "++++update page "
    start_time = Time.now
    setup
    set_loggable_projects
    @wktime = nil
    errorMsg = nil
    respMsg = nil
    findWkTE(@startday)
    @wktime = getWkEntity if @wktime.nil?
    allowApprove = false
    if api_request?
      errorMsg = gatherAPIEntries
      errorMsg = validateMinMaxHr(@startday) if errorMsg.blank?
      total = @total
      #allowApprove = true if check_approvable_status
    else
      total = params[:total].to_f
      gatherEntries
      allowApprove = true
    end
    errorMsg = gatherWkCustomFields(@wktime) if @wkvalidEntry && errorMsg.blank?
    wktimeParams = params[:wktime]
    cvParams = wktimeParams[:custom_field_values] unless wktimeParams.blank?
    useApprovalSystem = (!Setting.plugin_redmine_wktime['wktime_use_approval_system'].blank? &&
        Setting.plugin_redmine_wktime['wktime_use_approval_system'].to_i == 1)
    @wktime.transaction do
      begin
        errorMsg
        if errorMsg.blank? && (!params[:wktime_save].blank? ||
            (!params[:wktime_submit].blank?))
          if !@wktime.nil? && ( @wktime.status == 'n' || @wktime.status == 'r' || @wktime.status == 'l1' || @wktime.status == 'l2')
            if (!@wktime.status == 'l1' || !@wktime.status == 'l2' || !@wktime.status == 'r' )
              @wktime.status = :n
            end
            # save each entry
            entrycount=0
            entrynilcount=0
            @entries.each do |entry|
              entry.save
              entrycount += 1
              entrynilcount += 1 if (entry.hours).blank?
              allowSave = true
              if (!entry.id.blank? && !entry.editable_by?(@user))
                allowSave = false
              end
              errorMsg = updateEntry(entry) if allowSave
              break unless errorMsg.blank?
              entry.delete if entry.hours == nil
            end

            if !params[:wktime_submit].blank? && useApprovalSystem
              @wktime.submitted_on = Date.today
              @wktime.submitter_id = User.current.id
              @wktime.status = :l1
              if !Setting.plugin_redmine_wktime['wktime_uuto_approve'].blank? &&
                  Setting.plugin_redmine_wktime['wktime_uuto_approve'].to_i == 1
                @wktime.status = :a
              end
            end
          end
          setTotal(@wktime,total)
          #if (errorMsg.blank? && total > 0.0)
          errorMsg = 	updateWktime if (errorMsg.blank? && ((!@entries.blank? && entrycount!=entrynilcount) || @teEntrydisabled))
        end

        if errorMsg.blank? && useApprovalSystem
          if !@wktime.nil? && @wktime.status == 's'
            if !params[:wktime_approve].blank? && allowApprove
              errorMsg = updateStatus(:a)
            elsif (!params[:wktime_reject].blank? || !params[:hidden_wk_reject].blank?) && allowApprove
              if api_request?
                teName = getTEName()
                if !params[:"wk_#{teName}"].blank? && !params[:"wk_#{teName}"][:notes].blank?
                  @wktime.notes = params[:"wk_#{teName}"][:notes]
                end
              else
                @wktime.notes = params[:wktime_notes] unless params[:wktime_notes].blank?
              end
              errorMsg = updateStatus(:r)
              if email_delivery_enabled?
                sendRejectionEmail
              end
            elsif !params[:wktime_unsubmit].blank?
              errorMsg = updateStatus(:n)
            end
          elsif !params[:wktime_unapprove].blank? && !@wktime.nil? && @wktime.status == 'a' && allowApprove
            errorMsg = updateStatus(:s)
          end
        end
      rescue Exception => e
        errorMsg = e.message
      end

      if errorMsg.nil?
        #when the are entries or it is not a save action
        if !@entries.blank? || !params[:wktime_approve].blank? ||
            (!params[:wktime_reject].blank? || !params[:hidden_wk_reject].blank?) ||
            !params[:wktime_unsubmit].blank? || !params[:wktime_unapprove].blank? ||
            ((!params[:wktime_submit].blank? || !cvParams.blank?) && total > 0.0 && @wkvalidEntry)
          respMsg = l(:notice_successful_update)
        else
          respMsg = l(:error_wktime_save_nothing)
        end
      else
        respMsg = l(:error_te_save_failed, :label => setEntityLabel, :error => errorMsg)
        raise ActiveRecord::Rollback
      end
      # Approved days for TimeEntry Updates
      wktime_helper = Object.new.extend(WktimeHelper)
      @approve_days = params[:approved_days] if params[:approved_days].present?
      if @approve_days.present?
        if params[:wktime_reject].present?
          sendRejectionEmail()
        end
        @approve_days.each do |approve_day|
          @find_time_entries = TimeEntry.where(:user_id=> params[:user_id], :spent_on => approve_day.to_date)
          if @find_time_entries.present?
            @sum = 0
            @hours_per_day = @find_time_entries.each { |a| @sum+=a.hours if a.hours  }
          end
          logtime_projects = []
          permissions = []
          if params[:time_entry].present?
            prj_entry = [];
            params[:time_entry].collect{|rec| prj_entry << rec['project_id']}
            prj_entry.uniq.each do |time_entry|
              project = Project.find(time_entry)
              logtime_projects << User.current.roles_for_project(project)
              if logtime_projects.flatten.present?
                logtime_projects.each do |log|
                  log.each do |rec|
                    permissions << rec.permissions
                    wktime_helper = Object.new.extend(WktimeHelper)
                    user = User.find(params[:user_id])
                    approve_status = wktime_helper.check_time_log_entry_for_approve(approve_day,user)
                    if approve_status==false
                      if permissions.flatten.present? && permissions.flatten.include?(:l3)
                        update_l1_or_l2_record(params, approve_day, project,'l3')
                      elsif  permissions.flatten.present? && permissions.flatten.include?(:l2)
                        update_l1_or_l2_record(params, approve_day, project,'l2')
                      elsif permissions.flatten.include?(:l1)
                        update_l1_record(params, approve_day, project)
                      end
                    end
                    permissions = []
                    @wktime.user_id = params[:user_id]
                    @wktime.statusupdate_on =Date.today
                    @wktime.statusupdater_id = User.current.id
                    @wktime.save if @wktime.present? && (@wktime.hours != nil )
                  end
                end
              else
                []
              end
              logtime_projects = []
            end
          end
          if !params[:wktime_submit].blank? && useApprovalSystem
            @wktime.submitted_on = Date.today
            @wktime.submitter_id = User.current.id
            @wktime.status = :l1
            if !Setting.plugin_redmine_wktime['wktime_uuto_approve'].blank? &&
                Setting.plugin_redmine_wktime['wktime_uuto_approve'].to_i == 1
              @wktime.status = :a
            end
          end
        end
      elsif params[:user_ids].present? && wktime_helper.check_bio_permission_list_user_id_project_id('l3',User.current.id,[params[:project_id].to_i])
        approve_l3
      elsif params[:user_ids].present? && wktime_helper.check_bio_permission_list_user_id_project_id('l2',User.current.id,[params[:project_id].to_i])
        approve_home_l2
      end
    end

    Rails.logger.info "------------ before view ----------------"
    Rails.logger.info "Time elapsed #{(Time.now - start_time)*1000} milliseconds"
    start_time = Time.now
    Rails.logger.info "---------- END -------------"



    respond_to do |format|
      format.html {
        if errorMsg.nil?
          flash[:notice] = respMsg
          #redirect_back_or_default :action => 'index'
          # redirect_to :action => 'index' , :tab => params[:tab]
          if !params[:user_ids].present?
            redirect_to :action => 'edit', :user_id => params[:user_id], :startday => @startday
          else
            redirect_to :action => 'index' , :tab => params[:tab]
          end
        else
          flash[:error] = respMsg
          if !params[:enter_issue_id].blank? && params[:enter_issue_id].to_i == 1
            redirect_to :action => 'edit', :user_id => params[:user_id], :startday => @startday,
                        :enter_issue_id => 1
          else
            redirect_to :action => 'edit', :user_id => params[:user_id], :startday => @startday
          end
        end
      }
      format.api{
        if errorMsg.blank?
          render :text => respMsg, :layout => nil
        else
          @error_messages = respMsg.split('\n')
          render :template => 'common/error_messages.api', :status => :unprocessable_entity, :layout => nil
        end
      }
    end

    Rails.logger.info "++++elapsed time raja+++++++++++"
    Rails.logger.info "Time elapsed #{(Time.now - start_time)*1000} milliseconds"
    Rails.logger.info "++++End +++++++"
  end

  def approve_l3
    @ids= params[:ids]
    @approved_dates=[]
    @rejected_dates=[]
    @user_ids = params[:user_ids]
    if @user_ids.present?
      user_id= @user_ids.first
      @sum='0'
      month = params[:startday].to_date
      deadline_date = UserUnlockEntry.dead_line_final_method
      if params[:enddate].to_date > deadline_date
        params[:enddate] = deadline_date
      end
      @approved_dates << (params[:startdate].to_date..params[:enddate].to_date).to_a
      p "++++++++++==@approved_dates++++++++++++="
      p @approved_dates
      p "+++++++++++++end +++++++++++++"
      approved_dates = @approved_dates.flatten
      @user_ids.each do |each_user|
        approved_dates.each do |each_date|
          wktime_helper = Object.new.extend(WktimeHelper)
          user = User.find(each_user)
          approve_status = wktime_helper.check_time_log_entry_for_approve(each_date,user)
          @wktime = Wktime.find_or_initialize_by_begin_date_and_user_id(:user_id=>each_user.to_i,:begin_date=>each_date.to_date,:project_id=>params[:project_id])
          if approve_status==false && (@wktime.status !="l3") && params[:wktime_approve].present?
            @wktime.pre_status = @wktime.status
            @wktime.status = 'l3'
          elsif approve_status==false && params[:wktime_unapprove].present?
            # @wktime.status = @wktime.pre_status
            if @wktime.pre_status.present? && @wktime.pre_status.to_s != "l3"
              @wktime.status = @wktime.pre_status
            else
              @wktime.status = 'n'
            end

          elsif  approve_status==false && (@wktime.status !="l3") && params[:wktime_reject].present?
            @wktime.status = 'r'
            Rejection.create(:user_id => each_user, :project_id => params[:project_id], :rejected_by =>User.current.id, :rejected_role=> 'l3', :comment =>params[:wktime_notes], :date => each_date.to_date )
            @rejected_dates << each_date
          end
          @wktime.user_id = each_user
          @wktime.hours = @sum if !@wktime.hours.present?
          @wktime.project_id = params[:project_id]
          @wktime.statusupdate_on =Date.today
          @wktime.statusupdater_id = User.current.id
          @wktime.save
        end
      end
      if  params[:wktime_reject].present?
        if email_delivery_enabled?
          sendRejectionEmail_L3_or_L2()
        end
      end
    else
    end

  end

  def approve_home_l2
    @ids= params[:ids]
    @approved_dates=[]
    @rejected_dates=[]
    #@project_ids = params[:project_ids]
    @user_ids = params[:user_ids]
    if @user_ids.present?
      user_id= @user_ids.first
      @sum='0'
      month = params[:startday].to_date
      # @approved_dates << (month.beginning_of_month..month.end_of_month).to_a
      deadline_date = UserUnlockEntry.dead_line_final_method
      if params[:enddate].to_date > deadline_date
        params[:enddate] = deadline_date
      end
      @approved_dates << (params[:startdate].to_date..params[:enddate].to_date).to_a
      approved_dates = @approved_dates.flatten
      wktime_helper = Object.new.extend(WktimeHelper)
      @user_ids.each do |each_user|
        approved_dates.each do |each_date|
          user = User.find(each_user)
          approve_status = wktime_helper.check_time_log_entry_for_approve(each_date,user)
          @wktime = Wktime.find_or_initialize_by_begin_date_and_user_id(:user_id=>each_user.to_i,:begin_date=>each_date.to_date,:project_id=>params[:project_id])
          if approve_status == false && (@wktime.status != "l3")

            if  params[:wktime_approve].present?
              @wktime.pre_status = @wktime.status
              @wktime.status = 'l2'
            elsif params[:wktime_unapprove].present?
              # @wktime.status = @wktime.pre_status
              if @wktime.pre_status.present? && @wktime.pre_status.to_s != "l2"
                @wktime.status = @wktime.pre_status
              else
                @wktime.status = 'n'
              end

            elsif  params[:wktime_reject].present? && (@wktime.status != "l2")

              @wktime.status = 'r'
              Rejection.create(:user_id => each_user, :project_id => params[:project_id], :rejected_by =>User.current.id, :rejected_role=> 'l2', :comment =>params[:wktime_notes], :date => each_date.to_date )
              @rejected_dates << each_date
              # sendRejectionEmail
              # if email_delivery_enabled?
              #   sendRejectionEmail()
              # end
            end
          end
          @wktime.user_id = each_user
          @wktime.hours = @sum if !@wktime.hours.present?
          @wktime.project_id = params[:project_id]
          @wktime.statusupdate_on =Date.today
          @wktime.statusupdater_id = User.current.id
          @wktime.save
        end
      end
      if  params[:wktime_reject].present?
        if email_delivery_enabled?
          sendRejectionEmail_L3_or_L2()
        end
      end
    else
    end
  end

  def deleterow
    if check_editPermission
      delete_from_wktime(params)
      if api_request?
        ids = gatherIDs
      else
        ids = params['ids']
      end
      delete(ids)
      respond_to do |format|
        format.text  {
          render :text => 'OK'
        }
        format.api {
          render_api_ok
        }
      end
    else
      respond_to do |format|
        format.text  {
          render :text => 'FAILED'
        }
        format.api {
          render_403
        }
      end
    end
  end


  def delete_from_wktime(params)

    @time_entries = TimeEntry.where(:id=>params[:ids])
    if @time_entries.present?
      @time_entries.each do |time_entry|
        wktime = Wktime.where(:user_id=>time_entry.user_id,:begin_date=>time_entry.spent_on).last
        wktime.delete if wktime.present?
      end
    end
  end

  # API
  def deleteEntries
    deleterow
  end

  def gatherIDs
    ids = Array.new
    entityNames = getEntityNames()
    entries = params[:"#{entityNames[1]}"]
    if !entries.blank?
      entries.each do |entry|
        ids << entry[:id]
      end
    end
    ids
  end

  def destroy
    setup
    #cond = getCondition('spent_on', @user.id, @startday, @startday+6)
    #TimeEntry.delete_all(cond)
    @entries = findEntries()
    @entries.each do |entry|
      entry.destroy()
    end
    cond = getCondition('begin_date', @user.id, @startday)
    deleteWkEntity(cond)
    respond_to do |format|
      format.html {
        flash[:notice] = l(:notice_successful_delete)
        redirect_back_or_default :action => 'index', :tab => params[:tab]
      }
      format.api  {
        render_api_ok
      }
    end
  end

  def new
    start_time = Time.now
    set_user_projects
    @selected_project = getSelectedProject(@manage_projects)
    # get the startday for current week
    @startday = getStartDay(Date.today)
    render :action => 'new'
    Rails.logger.info "++++elapsed time raja+++++++++++"
    Rails.logger.info "Time elapsed #{(Time.now - start_time)*1000} milliseconds"
    Rails.logger.info "++++End +++++++"
  end

  def getIssueAssignToUsrCond
    issueAssignToUsrCond=nil
    if (!params[:issue_assign_user].blank? && params[:issue_assign_user].to_i == 1)
      issueAssignToUsrCond ="and (#{Issue.table_name}.assigned_to_id=#{params[:user_id]} OR #{Issue.table_name}.author_id=#{params[:user_id]})"
    end
    issueAssignToUsrCond
  end

  def getIssueAssignToUsrCond_query
    getIssueAssignToUsrCond_query=nil
    if (!params[:issue_assign_user].blank? && params[:issue_assign_user].to_i == 1)
      getIssueAssignToUsrCond_query ="and i.assigned_to_id=#{params[:user_id]} OR i.author_id=#{params[:user_id]}"
    end
    getIssueAssignToUsrCond_query
  end

  def getissues
    projectids = []
    if !params[:term].blank?
      subjectPart = (params[:term]).to_s.strip
      set_loggable_projects
      @logtime_projects.each do |project|
        projectids << project.id
      end
    end
    issueAssignToUsrCond = getIssueAssignToUsrCond
    trackerIDCond=nil
    trackerid=nil
    #If click addrow or project changed, tracker list does not show, get tracker value from settings page
    if  !filterTrackerVisible() && (params[:tracker_id].blank? || !params[:term].blank?)
      params[:tracker_id] = Setting.plugin_redmine_wktime[getTFSettingName()]
      trackerIDCond= "AND #{Issue.table_name}.tracker_id in(#{(Setting.plugin_redmine_wktime[getTFSettingName()]).join(',')})" if !params[:tracker_id].blank? && params[:tracker_id] != ["0"]
    end
    if Setting.plugin_redmine_wktime['wktime_closed_issue_ind'].to_i == 1
      if !params[:tracker_id].blank? && params[:tracker_id] != ["0"] && params[:term].blank?
        issues = Issue.find_all_by_project_id(params[:project_id] || params[:project_ids] ,
                                              :conditions =>  ["#{Issue.table_name}.tracker_id in ( ?) #{issueAssignToUsrCond}", params[:tracker_id]] , :order => 'project_id')
      elsif !params[:term].blank?
        if subjectPart.present?
          if subjectPart.match(/^\d+$/)
            cond = ["(LOWER(#{Issue.table_name}.subject) LIKE ? OR #{Issue.table_name}.id=?)#{issueAssignToUsrCond} #{trackerIDCond}", "%#{subjectPart.downcase}%","#{subjectPart.to_i}"]
          else
            cond = ["LOWER(#{Issue.table_name}.subject) LIKE ? #{issueAssignToUsrCond}#{trackerIDCond}", "%#{subjectPart.downcase}%"]
          end
          issues = Issue.find_all_by_project_id(params[:project_id] || params[:project_ids] || projectids ,
                                                :conditions => cond , :order => 'project_id')
        end
      else
        if (!params[:issue_assign_user].blank? && params[:issue_assign_user].to_i == 1)
          issues = Issue.find_all_by_project_id(params[:project_id] || params[:project_ids]|| projectids,:conditions =>["(#{Issue.table_name}.assigned_to_id= ? OR #{Issue.table_name}.author_id= ?)#{trackerIDCond}", params[:user_id],params[:user_id]], :order => 'project_id')
        else
          issues = Issue.find_all_by_project_id(params[:project_id] || params[:project_ids], :order => 'project_id')
        end
      end
    else
      @startday = params[:startday].to_s.to_date

      if !params[:tracker_id].blank? && params[:tracker_id] != ["0"]	&& params[:term].blank?

        cond = ["(#{IssueStatus.table_name}.is_closed = ? OR #{Issue.table_name}.updated_on >= ?) AND  #{Issue.table_name}.tracker_id in ( ?) #{issueAssignToUsrCond}", false, @startday,params[:tracker_id]]
      elsif !params[:term].blank?
        if subjectPart.present?
          if subjectPart.match(/^\d+$/)
            cond = ["(LOWER(#{Issue.table_name}.subject) LIKE ? OR #{Issue.table_name}.id=?)  AND #{IssueStatus.table_name}.is_closed = ? #{issueAssignToUsrCond} #{trackerIDCond}", "%#{subjectPart.downcase}%","#{subjectPart.to_i}",false]
          else
            cond = ["(LOWER(#{Issue.table_name}.subject) LIKE ?  AND #{IssueStatus.table_name}.is_closed = ?) #{issueAssignToUsrCond} #{trackerIDCond}", "%#{subjectPart.downcase}%",false]
          end
        end
      else

        cond =["(#{IssueStatus.table_name}.is_closed = ? OR #{Issue.table_name}.updated_on >= ?) #{issueAssignToUsrCond}#{trackerIDCond}", false, @startday]
      end

      issues= Issue.find_all_by_project_id(params[:project_id] || params[:project_ids] || projectids,
                                           :conditions => cond,
                                           :include => :status, :order => 'project_id')
    end
    issues.compact!

    user = User.find(params[:user_id])

    if  !params[:format].blank?
      respond_to do |format|
        format.text  {
          issStr =""
          issues.each do |issue|
            issStr << issue.project_id.to_s() + '|' + issue.id.to_s() + '|' + issue.tracker.to_s() +  '|' +
                issue.subject  + "\n" if issue.visible?(user)
          end
          render :text => issStr
        }
      end
    else
      issStr=[]
      issues.each do |issue|
        issStr << {:value => issue.id.to_s(), :label => issue.tracker.to_s() +  " #" + issue.id.to_s() + ": " + issue.subject }  if issue.visible?(user)
      end

      render :json => issStr
    end
  end



  def getactivities
    project = nil
    error = nil
    project_id = params[:project_id]
    if !project_id.blank?
      project = Project.find(project_id)
    elsif !params[:issue_id].blank?
      issue = Issue.find(params[:issue_id])
      project = issue.project
      project_id = project.id
      u_id = params[:user_id]
      user = User.find(u_id)
      if !user_allowed_to?(:log_time, project)
        error = "403"
      end
    else
      error = "403"
    end
    actStr =""
    project.activities.each do |a|
      actStr << project_id.to_s() + '|' + a.id.to_s() + '|' + a.name + "\n"
    end

    respond_to do |format|
      format.text  {
        if error.blank?
          render :text => actStr
        else
          render_403
        end
      }
    end
  end

  def getusers
    project = Project.find(params[:project_id])
    userStr =""
    projmembers = project.members.order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC")
    projmembers.each do |m|
      userStr << m.user_id.to_s() + ',' + m.name + "\n"
    end

    respond_to do |format|
      format.text  { render :text => userStr }
    end
  end

  # Export wktime to a single pdf file
  def export
    respond_to do |format|
      @new_custom_field_values = getNewCustomField
      @entries = findEntries()
      findWkTE(@startday)
      unitLabel = getUnitLabel
      format.pdf {
        send_data(wktime_to_pdf(@entries, @user, @startday,unitLabel), :type => 'application/pdf', :filename => "#{@startday}-#{params[:user_id]}.pdf")
      }
      format.csv {
        send_data(wktime_to_csv(@entries, @user, @startday,unitLabel), :type => 'text/csv', :filename => "#{@startday}-#{params[:user_id]}.csv")
      }
    end
  end

  def getLabelforSpField
    l(:field_hours)
  end

  def getCFInRowHeaderHTML
    "wktime_cf_in_row_header"
  end

  def getCFInRowHTML
    "wktime_cf_in_row"
  end


  def getTFSettingName
    "wktime_issues_filter_tracker"
  end

  def filterTrackerVisible
    !Setting.plugin_redmine_wktime['wktime_allow_user_filter_tracker'].blank?  && Setting.plugin_redmine_wktime['wktime_allow_user_filter_tracker'].to_i == 1
  end

  def getUnit(entry)
    nil
  end

  def getUnitDDHTML
    nil
  end

  def getUnitLabel
    nil
  end

  def showWorktimeHeader
    !Setting.plugin_redmine_wktime['wktime_work_time_header'].blank? &&
        Setting.plugin_redmine_wktime['wktime_work_time_header'].to_i == 1
  end

  def maxHour
    Setting.plugin_redmine_wktime['wktime_restr_max_hour'].to_i == 1 ?
        (Setting.plugin_redmine_wktime['wktime_max_hour_day'].blank? ? 8 : Setting.plugin_redmine_wktime['wktime_max_hour_day']) : 0
  end
  def minHour
    Setting.plugin_redmine_wktime['wktime_restr_min_hour'].to_i == 1 ?
        (Setting.plugin_redmine_wktime['wktime_min_hour_day'].blank? ? 0 : Setting.plugin_redmine_wktime['wktime_min_hour_day']) : 0
  end

  def total_all(total)
    html_hours(l_hours(total))
  end

  def getStatus
    status = getTimeEntryStatus(params[:startDate].to_date,User.current.id)
    respond_to do |format|
      format.text  { render :text => status }
    end
  end

  def setLimitAndOffset
    p '------ am test pa ------------------'
    p params
    p '--------'
    if api_request?
      @offset, @limit = api_offset_and_limit
      if !params[:limit].blank?
        @limit = params[:limit]
      end
      if !params[:offset].blank?
        @offset = params[:offset]
      end
    else
      @entry_pages = Paginator.new self, @entry_count, per_page_option, params['page']

      @limit = @entry_pages.items_per_page
      @offset = @entry_pages.current.offset
    end
  end

  def getMembersbyGroup
    group_by_users=""
    userList=[]
    set_managed_projects
    userList = getMembers
    userList.each do |users|
      group_by_users << users.id.to_s() + ',' + users.name + "\n"
    end
    respond_to do |format|
      format.text  { render :text => group_by_users }
    end
  end

  def findTEProjects()
    entityNames = getEntityNames
    Project.find_by_sql("SELECT DISTINCT p.* FROM projects p INNER JOIN " + entityNames[1] + " t ON p.id=t.project_id  where t.spent_on BETWEEN '" + @startday.to_s +
                            "' AND '" +  (@startday+6).to_s + "' AND t.user_id = " + @user.id.to_s)
  end

  def check_approvable_status
    te_projects=[]
    if !@entries.blank?
      @te_projects = @entries.collect{|entry| entry.project}.uniq
      te_projects = @approvable_projects & @te_projects if !@te_projects.blank?
    end
    (!te_projects.blank? && (@user.id != User.current.id ||(!Setting.plugin_redmine_wktime[:wktime_own_approval].blank? &&
        Setting.plugin_redmine_wktime[:wktime_own_approval].to_i == 1 )))? true: false
  end

  def check_approvable_status_l1(startday)
    end_day = (startday + 6)
    @status = Wktime.where(begin_date: startday..end_day,status: "l1")
    if @status.present?
      return true
    end
  end
  def check_approvable_status_l2(startday)
    end_day = (startday + 6)
    @status = Wktime.where(begin_date: startday..end_day,status: "l2")
    if @status.present?
      return true
    end
  end
  def check_approvable_status_l3(startday,end_day)
    # startday = startday.beginning_of_month
    # end_day = startday.end_of_month
    @status = Wktime.where(begin_date: startday..end_day,status: "l3")
    if @status.present?
      return true
    end
  end
  def check_approvable_status_home_l2(startday,end_day)
    @status = Wktime.where(begin_date: startday..end_day,status: "l2")
    if @status.present?
      return true
    end
  end

  def testapi
    respond_to do |format|
      format.html {
        render :layout => !request.xhr?
      }
    end
  end



# to change the status to locked user to unlock
  def unlock_users
    #@@unlock_status = find_lock_users(params[:user_id])

    @update_unlock_status = update_unlock_details(params)
    @lock_status = UserUnlockEntry.where(:user_id=>params[:user_id])
    respond_to do |format|
      format.html { redirect_to_settings_in_projects }
      format.js
      format.api {
        if @update_unlock_status == true
          render_api_ok
        else
          render_validation_errors(@update_unlock_status)
        end
      }
    end
  end

  def unlock_permanent

    #@@unlock_status = find_lock_users(params[:user_id])
    @user = User.where(id:params[:user_id]).last
    permanent_unlock = PermanentUnlock.where(:user_id=>@user.id)
    if @user.permanent_unlock.present? && permanent_unlock.last.status.present?
      if permanent_unlock.last.status == true
        permanent_unlock.last.update_attributes(:status=> false)
      else
        permanent_unlock.last.update_attributes(:status=> true,:comment=>params[:comments])
      end
    else
      permanent_unlock = PermanentUnlock.find_or_create_by_user_id(:user_id=>@user.id)
      permanent_unlock.update_attributes(:status=> true,:comment=>params[:comments])
    end

    #@update_unlock_status = update_unlock_details(params)
    #@lock_status = UserUnlockEntry.where(:user_id=>params[:user_id])
    respond_to do |format|
      format.js
      format.api {
        render_api_ok

      }
    end
  end


  # find user log and update the status
  def find_lock_users(user_id)
    locked_users = LockUserEntry.where(:user_id =>user_id, :lock => true)
    if locked_users.present?
      locked_users.each do |user|
        user.update_attributes(:lock=> false)
      end
      return true
    end
  end

  # to cfreate a new entry to whom provide a permission to unlock the log status
  def update_unlock_details(params)
    setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    deadline_date = UserUnlockEntry.dead_line_for_lock(current_time)
    expire_time = wktime_helper.return_time_zone.parse("#{deadline_date.year}-#{deadline_date.month}-#{deadline_date.day} #{setting_hr}:#{setting_min}")
    if expire_time <= current_time
      expire_unlock_time =(expire_time)
    else
      expire_unlock_time =(expire_time)
    end
    user = UserUnlockEntry.new(:user_id=> params[:user_id],:manager_id=>User.current.id,:updated_by=>User.current.id,:comment=>params[:comment],:expire_time=>expire_unlock_time)

    if user.save
      UserUnlockHistory.create(:user_id=> params[:user_id],:manager_id=>User.current.id,:updated_by=>User.current.id,:comment=>params[:comment],:expire_time=>expire_unlock_time,:date=>Date.today,:created_at=>Date.today)
      return true
    else
      return user
    end
  end




  def lock_users
    lock_status = UserUnlockEntry.where(:user_id=>params[:user_id])
    if lock_status.present?
      lock_status.destroy_all
    end

    respond_to do |format|
      format.js
      format.api {
        render_api_ok

      }
    end

  end


  private


  def check_permission
    ret = false;
    setup
    set_user_projects
    status = getTimeEntryStatus(@startday,@user_id)
    approve_projects = @approvable_projects & @logtime_projects
    if (status != 'n' && (!approve_projects.blank? && approve_projects.size > 0))
      #for approver
      ret = true
    else
      if !@manage_projects.blank? && @manage_projects.size > 0
        #for manager
        if !@logtime_projects.blank? && @logtime_projects.size > 0
          manage_log_projects = @manage_projects & @logtime_projects
          ret = (!manage_log_projects.blank? && manage_log_projects.size > 0)
        end
      else
        #for individuals
        ret = (@user.id == User.current.id && @logtime_projects.size > 0)
      end
    end
    return ret

  end


  def getUsersbyGroup
    groupusers= nil
    scope=User.in_group(params[:group_id])  if params[:group_id].present?
    groupusers =scope.all
  end

  def getMembers
    projMembers = []
    groupbyusers = []
    groupusers = getUsersbyGroup
    projMembers = Principal.member_of(@manage_view_spenttime_projects)
    groupbyusers = groupusers & projMembers
    groupbyusers=groupbyusers.sort
  end

  def getCondition(date_field, user_id, start_date, end_date=nil)
    cond = nil
    if end_date.nil?
      cond = user_id.nil? ? [ date_field + ' = ?', start_date] :
          [ date_field + ' = ? AND user_id = ?', start_date, user_id]
    else
      cond = user_id.nil? ? [ date_field + ' BETWEEN ? AND ?', start_date, end_date] :
          [ date_field + ' BETWEEN ? AND ? AND user_id = ?', start_date, end_date, user_id]
    end
    return cond
  end

  #change the date to a last day of week
  def getEndDay(date)
    start_of_week = getStartOfWeek
    #Martin Dube contribution: 'start of the week' configuration
    unless date.nil?
      daylast_diff = (6 + start_of_week) - date.wday
      date += (daylast_diff%7)
    end
    date
  end

  def prevTemplate(user_id)
    prev_entries = nil
    noOfWeek = Setting.plugin_redmine_wktime['wktime_previous_template_week']

    if !noOfWeek.blank?
      entityNames = getEntityNames
      sDay= getDateSqlString('t.spent_on')
      sqlStr = "select t.* from " + entityNames[1] + " t inner join ( "
      if ActiveRecord::Base.connection.adapter_name == 'SQLServer'
        sqlStr += "select TOP " + noOfWeek.to_s + sDay + " as startday" +
            " from  " + entityNames[1] + " t where user_id = " + user_id.to_s +
            " group by " + sDay + " order by startday desc ) as v"
      else
        sqlStr += "select " + sDay + " as startday" +
            " from  " + entityNames[1] + " t where user_id = " + user_id.to_s +
            " group by startday order by startday desc limit " + noOfWeek.to_s + ") as v"
      end

      sqlStr +=" on " + sDay + " = v.startday where user_id = " + user_id.to_s +
          " order by t.project_id, t.issue_id, t.activity_id"

      prev_entries = TimeEntry.find_by_sql(sqlStr)
    end
    prev_entries
  end


  def gatherEntries
    entryHash = params[:time_entry]
    @entries ||= Array.new
    custom_values = Hash.new
    #setup
    decimal_separator = l(:general_csv_decimal_separator)
    use_detail_popup = !Setting.plugin_redmine_wktime['wktime_use_detail_popup'].blank? &&
        Setting.plugin_redmine_wktime['wktime_use_detail_popup'].to_i == 1
    custom_fields = TimeEntryCustomField.find(:all)
    @wkvalidEntry=false
    @teEntrydisabled=false
    unless entryHash.nil?
      entryHash.each_with_index do |entry, i|
        if !entry['project_id'].blank?
          hours = params['hours' + (i+1).to_s()]
          ids = params['ids' + (i+1).to_s()]
          comments = params['comments' + (i+1).to_s()]
          disabled = params['disabled' + (i+1).to_s()]
          @wkvalidEntry=true
          if use_detail_popup
            custom_values.clear
            custom_fields.each do |cf|
              custom_values[cf.id] = params["_custom_field_values_#{cf.id}" + (i+1).to_s()]
            end
          end
          j = 0
          ids.each_with_index do |id, k|
            if disabled[k] == "false"
              if(!id.blank? || !hours[j].blank?)
                teEntry = nil
                teEntry = getTEEntry(id)
                teEntry.attributes = entry
                # since project_id and user_id is protected
                teEntry.project_id = entry['project_id']
                teEntry.user_id = @user.id
                teEntry.spent_on = @startday + k
                #for one comment, it will be automatically loaded into the object
                # for different comments, load it separately
                unless comments.blank?
                  teEntry.comments = comments[k].blank? ? nil : comments[k]
                end
                #timeEntry.hours = hours[j].blank? ? nil : hours[j].to_f
                #to allow for internationalization on decimal separator
                setValueForSpField(teEntry,hours[j],decimal_separator,entry)

                unless custom_fields.blank?
                  teEntry.custom_field_values.each do |custom_value|
                    custom_field = custom_value.custom_field

                    #if it is from the row, it should be automatically loaded
                    if !((!Setting.plugin_redmine_wktime['wktime_enter_cf_in_row1'].blank? &&
                        Setting.plugin_redmine_wktime['wktime_enter_cf_in_row1'].to_i == custom_field.id) ||
                        (!Setting.plugin_redmine_wktime['wktime_enter_cf_in_row2'].blank? &&
                            Setting.plugin_redmine_wktime['wktime_enter_cf_in_row2'].to_i == custom_field.id))
                      if use_detail_popup
                        cvs = custom_values[custom_field.id]
                        custom_value.value = cvs[k].blank? ? nil :
                            custom_field.multiple? ? cvs[k].split(',') : cvs[k]
                      end
                    end
                  end
                end
                @entries << teEntry
              end
              j += 1
            else
              @teEntrydisabled=true
            end
          end
        end
      end
    end
  end

  def gatherWkCustomFields(wktime)
    errorMsg = nil
    cvParams = nil
    if api_request?
      teName = getTEName()
      wktimeParams = params[:"wk_#{teName}"][:custom_fields]
      cvParams = getAPIWkCustomFields(wktimeParams)	unless wktimeParams.blank?
    else
      wktimeParams = params[:wktime]
      cvParams = wktimeParams[:custom_field_values] unless wktimeParams.blank?
    end
    #custom_values = Hash.new
    custom_fields = WktimeCustomField.find(:all)
    if !custom_fields.blank? && !cvParams.blank?
      wktime.custom_field_values.each do |custom_value|
        custom_field = custom_value.custom_field
        cvs = cvParams["#{custom_field.id}"]
        if cvs.blank? && custom_field.is_required
          errorMsg = "#{custom_field.name} #{l('activerecord.errors.messages.blank')} "
          break
        end
        custom_value.value = cvs.blank? ? nil :
            custom_field.multiple? ? cvs.split(',') : cvs
      end
    end
    return errorMsg
  end

  def getAPIWkCustomFields(wktimeParams)
    wkCustField = wktimeParams
    custFldValues = nil
    if !wkCustField.blank?
      custFldValues = Hash.new
      wkCustField.each do |cf|
        custFldValues["#{cf[:id]}"] = cf[:value]
      end
    end
    custFldValues
  end

  def gatherAPIEntries
    errorMsg = nil
    wkte_entries = Hash.new
    teName = getTEName()
    entityNames = getEntityNames()
    @entries = Array.new
    decimal_separator = l(:general_csv_decimal_separator)
    @total = 0
    spField = getSpecificField()
    createSpentOnHash(@startday)
    @wkvalidEntry = true
    @teEntrydisabled=true
    begin
      wkte_entries = params[:"wk_#{teName}"][:"#{entityNames[1]}"]
      if !wkte_entries.blank?
        wkte_entries.each do |entry|
          if !entry[:project].blank?
            id = entry[:id]
            teEntry = nil
            teEntry = getTEEntry(id)
            teEntry.safe_attributes = entry
            if (!entry[:user].blank? && !entry[:user][:id].blank? && @user.id != entry[:user][:id].to_i)
              raise "#{l(:field_user)} #{l('activerecord.errors.messages.invalid')}"
            else
              teEntry.user_id = @user.id
            end
            if !@hrPerDay.has_key?(entry[:spent_on])
              raise "#{l(:label_date)} #{l('activerecord.errors.messages.invalid')}"
            end
            teEntry.project_id = entry[:project][:id] if !entry[:project].blank?
            if (Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].blank? && (entry[:issue].blank? || entry[:issue][:id].blank?))
              raise "#{l(:field_issue)} #{l('activerecord.errors.messages.blank')} "
            else
              if !entry[:issue].blank? && !entry[:issue][:id].blank?
                teEntry.issue_id = entry[:issue][:id]
              else
                teEntry.issue_id = nil
              end
            end
            teEntry.activity_id = entry[:activity][:id] if !entry[:activity].blank?
            setValueForSpField(teEntry,(entry[:"#{spField}"].to_s),decimal_separator,entry)
            @hrPerDay[entry[:spent_on]] = "#{@hrPerDay[entry[:spent_on]]}".to_f + (entry[:"#{spField}"].to_s).gsub(decimal_separator, '.').to_f
            @total = @total + (entry[:"#{spField}"].to_s).gsub(decimal_separator, '.').to_f
            @entries << teEntry
          end
        end
      end
    rescue Exception => e
      errorMsg = e.message
    end
    errorMsg
  end

  def findEntries
    setup
    cond = getCondition('spent_on', @user.id, @startday, @startday+6)
    findEntriesByCond(cond)
  end

  def findWkTE(start_date, end_date=nil)
    #setup

    cond = getCondition('begin_date', @user.nil? ? nil : @user.id, start_date, end_date)
    p "++++++++++cond++++++++++"
    p cond
    p "++++++++end +++++++++"
    findWkTEByCond(cond)
    @wktime = @wktimes[0] unless @wktimes.blank?
  end

  def findWkTEHash(start_date, end_date)
    @wktimesHash ||= Hash.new
    @wktimesHash.clear
    findWkTE(start_date, end_date)
    @wktimes.each do |wktime|
      @wktimesHash[wktime.user_id.to_s + wktime.begin_date.to_s] = wktime
    end
  end

  def render_edit
    set_user_projects
    render :action => 'edit', :user_id => params[:user_id], :startday => @startday
  end

  def check_perm_and_redirect
    unless check_permission
      render_403
      return false
    end
  end

  def user_allowed_to?(privilege, entity)
    setup
    return @user.allowed_to?(privilege, entity)
  end

  def can_log_time?(project_id)
    ret = false
    set_loggable_projects
    @logtime_projects.each do |lp|
      if lp.id == project_id
        ret = true
        break
      end
    end
    return ret
  end



  def check_editperm_redirect
    unless check_editPermission
      render_403
      return false
    end
  end

  def check_editPermission
    allowed = true;
    if api_request?
      ids = gatherIDs
    else
      ids = params['ids']
    end
    if !ids.blank?
      @entries = findTEEntries(ids)
    else
      setup
      cond = getCondition('spent_on', @user.id, @startday, @startday+6)
      @entries = findEntriesByCond(cond)
    end
    @entries.each do |entry|
      if(!entry.editable_by?(User.current))
        allowed = false
        break
      end
    end
    return allowed
  end

  def updateEntry(entry)
    p "++++==entry+++++++update"
    p entry
    p "++++++end +++++++"
    errorMsg = nil
    if entry.hours.blank?
      # delete the time_entry
      # if the hours is empty but id is valid
      # entry.destroy() unless ids[i].blank?
      if !entry.id.blank?
        if !entry.destroy()
          errorMsg = entry.errors.full_messages.join('\n')
        end
      end
    else
      #if id is there it should be update otherwise create
      #the UI disables editing of
      if can_log_time?(entry.project_id)
        if !entry.save()
          errorMsg = entry.errors.full_messages.join('\n')
        end
      else
        errorMsg = l(:error_not_permitted_save)
      end
    end
    return errorMsg
  end

  def updateWktime
    errorMsg = nil
    @wktime.begin_date = @startday
    @wktime.user_id = @user.id
    @wktime.statusupdater_id = User.current.id
    @wktime.statusupdate_on = Date.today
    if !@wktime.save()
      errorMsg = @wktime.errors.full_messages.join('\n')
    end
    return errorMsg
  end

  # update timesheet status
  def updateStatus(status)
    errorMsg = nil
    if @wktimes.blank?
      errorMsg = l(:error_wktime_save_nothing)
    else
      @wktime.statusupdater_id = User.current.id
      @wktime.statusupdate_on = Date.today
      @wktime.status = status
      if !@wktime.save()
        errorMsg = @wktime.errors.full_messages.join('\n')
      end
    end
    return errorMsg
  end

  # delete a timesheet
  def deleteWktime
    errorMsg = nil
    unless @wktime.nil?
      if !@wktime.destroy()
        errorMsg = @wktime.errors.full_messages.join('\n')
      end
    end
    return errorMsg
  end

  # Retrieves the date range based on predefined ranges or specific from/to param dates
  def retrieve_date_range
    @free_period = false
    @from, @to = nil, nil

    if params[:period_type] == '1' || (params[:period_type].nil? && !params[:period].nil?)
      case params[:period].to_s
        when 'today'
          @from = @to = Date.today
        when 'yesterday'
          @from = @to = Date.today - 1
        when 'current_week'
          @from = getStartDay(Date.today - (Date.today.cwday - 1)%7)
          @to = @from + 6
        when 'last_week'
          @from =getStartDay(Date.today - 7 - (Date.today.cwday - 1)%7)
          @to = @from + 6
        when '7_days'
          @from = Date.today - 7
          @to = Date.today
        when 'current_month'
          @from = Date.civil(Date.today.year, Date.today.month, 1)
          @to = (@from >> 1) - 1
        when 'last_month'
          @from = Date.civil(Date.today.year, Date.today.month, 1) << 1
          @to = (@from >> 1) - 1
        when '30_days'
          @from = Date.today - 30
          @to = Date.today
        when 'current_year'
          @from = Date.civil(Date.today.year, 1, 1)
          @to = Date.civil(Date.today.year, 12, 31)
        when 'all'
          @from = Date.civil(Date.today.year, 1, 1)
          @to = Date.civil(Date.today.year, 12, 31)
      end
    elsif params[:period_type] == '2' || (params[:period_type].nil? && (!params[:from].nil? || !params[:to].nil?))
      begin; @from = params[:from].to_s.to_date unless params[:from].blank?; rescue; end
      begin; @to = params[:to].to_s.to_date unless params[:to].blank?; rescue; end
      @free_period = true
    else
      # default
      # 'current_month'
      @from = Date.civil(Date.today.year, Date.today.month, 1)
      @to = (@from >> 1) - 1
    end

    @from, @to = @to, @from if @from && @to && @from > @to

    p "++++++==@from+++++++@from++++"
    p @from
    p "+++++to ++++to ++++"
    p @to

  end

  # show all groups and project/group members show
  def setgroups
    @groups = Group.sorted.all
    @members = Array.new
    if params[:projgrp_type] == '2'
      userLists=[]
      userLists = getMembers
      @use_group=true
      userLists.each do |users|
        @members << [users.name,users.id.to_s()]
      end
    else
      @use_group=false
      #@members=@selected_project.members.collect{|m| [ m.name, m.user_id ] }.sort
      projmem= @selected_project.members.order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC")
      @members=projmem.collect{|m| [ m.name, m.user_id ] }
    end
  end

  def setup
    teName = getTEName()
    if api_request? && params[:startday].blank?
      startday = params[:"wk_#{teName}"][:startday].to_s.to_date
    else
      startday = params[:startday].to_s.to_date
    end
    if api_request? && params[:user_id].blank?
      user_id = params[:"wk_#{teName}"][:user][:id]
    else
      user_id = params[:user_id]
    end
    # if user has changed the startday
    @startday ||= getStartDay(startday)
    @user ||= User.find(user_id)
  end

  def set_user_projects
    set_loggable_projects
    set_managed_projects
    set_approvable_projects
  end

  def set_managed_projects
    # from version 1.7, the project member with 'edit time logs' permission is considered as managers
    @manage_projects ||= Project.find(:all, :order => 'name',
                                      :conditions => Project.allowed_to_condition(User.current, :edit_time_entries))
    @manage_projects =	setTEProjects(@manage_projects)

    # @manage_view_spenttime_projects contains project list of current user with edit_time_entries and view_time_entries permission
    # @manage_view_spenttime_projects is used to fill up the dropdown in list page for managers
    view_spenttime_projects ||= Project.find(:all, :order => 'name',
                                             :conditions => Project.allowed_to_condition(User.current, :view_time_entries))
    @manage_view_spenttime_projects = @manage_projects & view_spenttime_projects
    @manage_view_spenttime_projects = setTEProjects(@manage_view_spenttime_projects)

    @currentUser_loggable_projects ||= Project.find(:all, :order => 'name',
                                                    :conditions => Project.allowed_to_condition(User.current, :log_time))
    @currentUser_loggable_projects = setTEProjects(@currentUser_loggable_projects)
  end

  def set_loggable_projects
    if api_request? && params[:user_id].blank?
      teName = getTEName()
      u_id = params[:"wk_#{teName}"][:user][:id]
    else
      u_id = params[:user_id]
    end
    if !u_id.blank?	&& u_id.to_i != 0
      @user ||= User.find(params[:user_id])
      @logtime_projects ||= Project.find(:all, :order => 'name',:conditions => Project.allowed_to_condition(@user, :log_time))
      @logtime_projects = setTEProjects(@logtime_projects)
    end
  end


  def set_project_issues(entries)
    @projectIssues ||= Hash.new
    @projActivities ||= Hash.new
    @projectIssues.clear
    @projActivities.clear
    count =  entries.map(&:project_id)
    count.uniq.each do |entry|
      set_visible_issues(entry)
    end
    set_visible_issues(nil)
  end


  def set_visible_issues(entry)
    if entry.is_a?(ActiveRecord::Base) || entry == nil
      project = entry.nil? ? (@logtime_projects.blank? ? nil : @logtime_projects[0]) : entry.project
      project_id = project.nil? ? 0 : project.id
    else
      # entry = Issue.find(entry)
      project =   Project.find(entry) #entry.project #
      project_id = entry#.project.id
    end
    issueAssignToUsrCond = getIssueAssignToUsrCond
    if @projectIssues[project_id].blank?
      allIssues = Array.new
      trackerids=nil
      if(!params[:tracker_ids].blank?)
        trackerids =" AND #{Issue.table_name}.tracker_id in(#{params[:tracker_ids]})"
      end
      if Setting.plugin_redmine_wktime['wktime_closed_issue_ind'].to_i == 1
        if !Setting.plugin_redmine_wktime[getTFSettingName()].blank? &&  Setting.plugin_redmine_wktime[getTFSettingName()] != ["0"] && params[:tracker_ids].blank?
          cond=["#{Issue.table_name}.tracker_id in ( ?) #{issueAssignToUsrCond} ",Setting.plugin_redmine_wktime[getTFSettingName()]]
          #allIssues = Issue.find_all_by_project_id(project_id , :conditions =>  ["#{Issue.table_name}.tracker_id in ( ?) ",Setting.plugin_redmine_wktime[getTFSettingName()]])
          allIssues = Issue.find_all_by_project_id(project_id,:conditions =>cond)
        else
          if (!params[:issue_assign_user].blank? && params[:issue_assign_user].to_i == 1)
            allIssues = Issue.find_all_by_project_id(project_id,:conditions =>["(#{Issue.table_name}.assigned_to_id= ? OR #{Issue.table_name}.author_id= ?) #{trackerids}", params[:user_id],params[:user_id]])
          else
            allIssues =  Issue.where(:project_id => project_id,:assigned_to_id => @user.id) + Issue.find(TimeEntry.where(:project_id => project_id, :user_id => @user.id, :spent_on => (@startday..(@startday + 6.days))).map(&:issue_id)) #Issue.find_all_by_project_id(project_id) #entry #
          end
        end
      else
        if !Setting.plugin_redmine_wktime[getTFSettingName()].blank? &&  Setting.plugin_redmine_wktime[getTFSettingName()] != ["0"] && params[:tracker_ids].blank?
          cond = ["(#{IssueStatus.table_name}.is_closed = ? OR #{Issue.table_name}.updated_on >= ?) AND  #{Issue.table_name}.tracker_id in ( ?) #{issueAssignToUsrCond} ",false, @startday,Setting.plugin_redmine_wktime[getTFSettingName()]]
        else
          cond =["(#{IssueStatus.table_name}.is_closed = ? OR #{Issue.table_name}.updated_on >= ?) #{issueAssignToUsrCond} #{trackerids}",false, @startday]
        end
        allIssues = Issue.find_all_by_project_id(project_id, :conditions => cond,  :include => :status)
      end
      @projectIssues[project_id] =   allIssues.select {|i| i.visible?(@user) }
    end
    if @projActivities[project_id].blank?
      @projActivities[project_id] = project.activities unless project.nil?
    end
  end



  def getSpecificField
    "hours"
  end

  def getEntityNames
    ["#{Wktime.table_name}", "#{TimeEntry.table_name}"]
  end

  def findBySql(selectStr,sqlStr,wkSelectStr,wkSqlStr)
    spField = getSpecificField()
    result = TimeEntry.find_by_sql("select count(*) as id from (" + selectStr + sqlStr + ") as v2")
    @entry_count = result[0].id
    setLimitAndOffset()
    rangeStr = formPaginationCondition()
    @entries = TimeEntry.find_by_sql(wkSelectStr + sqlStr + wkSqlStr + rangeStr)
    @entries = @entries.uniq{|x| [x.spent_on,x.user_id] } if @entries.present?
    #@entries = @entries.uniq{|x| x.user_id && x.spent_on } if @entries.present?

    @unit = nil
    #@total_hours = TimeEntry.visible.sum(:hours, :include => [:user], :conditions => cond.conditions).to_f

    result = TimeEntry.find_by_sql("select sum(v2." + spField + ") as " + spField + " from (" + selectStr + sqlStr + ") as v2")
    @total_hours = result[0].hours
  end

  def findWkTEByCond(cond)
    @wktimes = Wktime.find(:all, :conditions => cond)
  end

  def findEntriesByCond(cond)
    TimeEntry.find(:all, :conditions => cond,
                   :order => 'project_id, issue_id, activity_id, spent_on')
  end

  def setValueForSpField(teEntry,spValue,decimal_separator,entry)
    if (!spValue.blank? && is_number(spValue.gsub(decimal_separator, '.')))
      teEntry.hours = spValue.gsub(decimal_separator, '.').to_f
    else
      teEntry.hours = nil
    end
  end


  def sendRejectionEmail
    raise_delivery_errors_old = ActionMailer::Base.raise_delivery_errors
    ActionMailer::Base.raise_delivery_errors = true

    begin
      unitLabel = getUnitLabel
      unit = params[:unit].to_s
      #@test = WkMailer.sendRejectionEmail(User.current,@user,@wktime,unitLabel,unit).deliver
      @test_mail = WkMailer.send_reject_dates(User.current,params[:user_id],params[:approved_days],params[:wktime_notes]).deliver
    rescue Exception => e
      flash[:error] = l(:notice_email_error, e.message)
    end
    ActionMailer::Base.raise_delivery_errors = raise_delivery_errors_old

  end




  def sendRejectionEmail_L3_or_L2
    raise_delivery_errors_old = ActionMailer::Base.raise_delivery_errors
    ActionMailer::Base.raise_delivery_errors = true

    begin
      unitLabel = getUnitLabel
      unit = params[:unit].to_s
      #@test = WkMailer.sendRejectionEmail(User.current,@user,@wktime,unitLabel,unit).deliver
      if  @user_ids.present? && @rejected_dates.present?
        @user_ids.each do |user|
          @test_mail = WkMailer.send_reject_dates(User.current,user,@rejected_dates,params[:wktime_notes]).deliver
        end
      end
    rescue Exception => e
      flash[:error] = l(:notice_email_error, e.message)
    end
    ActionMailer::Base.raise_delivery_errors = raise_delivery_errors_old

  end


  def l1_not_approve_days
    @users =  User.active
    if @users.present?
      @users.each do |user|
        @projects = []
        if user.projects.present?
          user.projects.each do |project|
            project = Project.where(id:project.id).last
            logtime_projects = user.roles_for_project(project)
            if project.present? && logtime_projects.present?
              if logtime_projects.last.permissions.include? "l1".to_sym
                project.members.each do |member|
                  wktime = Wktime.where(:user_id => user.id,:begin_date=>Date.today)
                  time_entry = TimeEntry.where(:user_id => user.id,:spent_on=>Date.today)

                  if time_entry.present? || (wktime.present? && (wktime.status != "l1") && (wktime.status != "l2") )

                    #  l1_not_approve_days(user,)
                  end

                end

              end
            end
          end



        end
      end

    end

    begin
      unitLabel = getUnitLabel
      unit = params[:unit].to_s
      #@test = WkMailer.sendRejectionEmail(User.current,@user,@wktime,unitLabel,unit).deliver
      @test_mail = WkMailer.send_reject_dates(User.current,params[:user_id],params[:approved_days],params[:wktime_notes]).deliver
    rescue Exception => e
      flash[:error] = l(:notice_email_error, e.message)
    end
    ActionMailer::Base.raise_delivery_errors = raise_delivery_errors_old

  end


  def getNewCustomField
    TimeEntry.new.custom_field_values
  end


  def getWkEntity
    Wktime.new
  end

  def getTEEntry(id)
    id.blank? ? TimeEntry.new : TimeEntry.find(id)
  end

  def deleteWkEntity(cond)
    Wktime.delete_all(cond)
  end

  def delete(ids)
    TimeEntry.delete(ids)
  end

  def findTEEntries(ids)
    TimeEntry.find(ids)
  end

  def setTotal(wkEntity,total)
    wkEntity.hours = total
  end

  def setEntityLabel
    l(:label_wktime)
  end

  def setTEProjects(projects)
    projects
  end

  def createSpentOnHash(stDate)
    @hrPerDay = Hash.new
    for i in 0..6
      key = (stDate+i)
      @hrPerDay["#{key}"] = 0
    end
  end

  def validateMinMaxHr(stDate)
    errorMsg = nil
    minHr = minHour().to_i
    maxHr = maxHour().to_i
    if minHr > 0 || maxHr > 0
      nwdays = Setting.non_working_week_days
      phdays = getWdayForPublicHday(stDate)
      holidays = nwdays.concat(phdays)
      for i in 0..6
        key = (stDate+i)
        if (!holidays.include?((key.cwday).to_s) || @hrPerDay["#{key}"] > 0)
          if minHr > 0 && !params[:wktime_submit].blank?
            if @hrPerDay["#{key}"] < minHr
              errorMsg = l(:text_wk_warning_min_hour, :value => "#{minHr}")
              break
            end
          end
          if  maxHr > 0
            if @hrPerDay["#{key}"] > maxHr
              errorMsg = l(:text_wk_warning_max_hour, :value => "#{maxHr}")
              break
            end
          end
        end
      end
    end
    errorMsg
  end

  def set_approvable_projects
    @approvable_projects ||= Project.find(:all, :order => 'name',
                                          :conditions => Project.allowed_to_condition(User.current, :approve_time_entries))
  end

  def getTEName
    "time"
  end

  def getSelectedProject(projList)
    selected_proj_id = params[:project_id]
    if !selected_proj_id.blank?
      sel_project = projList.select{ |proj| proj.id == selected_proj_id.to_i }
      selected_project ||= sel_project[0] if !sel_project.blank?
    else
      selected_project ||= projList[0] if !projList.blank?
    end
  end

  def check_view_redirect
    # the user with view_time_entries permission will only be allowed to view list page
    unless checkViewPermission
      render_403
      return false
    end
  end

  def check_log_time_redirect
    set_user_projects
    # the user with log_time(for member) or edit time log(for manager) permission will be allowed to enter new time/expense sheet
    if !@currentUser_loggable_projects.blank? || !@manage_projects.blank?
      return true
    else
      render_403
      return false
    end
  end

  def formPaginationCondition
    rangeStr = ""
    if ActiveRecord::Base.connection.adapter_name == 'SQLServer'
      status = params[:status]
      if !status.blank? && status != 'all'
        rangeStr = " AND (rownum > " + @offset.to_s  + " AND rownum <= " + (@offset  + @limit ).to_s + ")"
      else
        rangeStr =" WHERE rownum > " + @offset.to_s  + " AND rownum <= " + (@offset  + @limit ).to_s
      end
    else
      rangeStr = 	" LIMIT " + @limit.to_s +	" OFFSET " + @offset.to_s
    end
    rangeStr
  end

  def update_l1_record(params, approve_day, project)
    # @wktime = Wktime.where(:user_id=>params[:user_id],:begin_date=>approve_day.to_date,:hours=>@sum,  :statusupdater_id => User.current.id, :project_id => project.id).first_or_initialize
    # @wktime = Wktime.find_or_create_by_user_id_and_project_id_and_status_and_begin_date(user_id:params[:user_id],project_id:project.id,status: 'l1',begin_date: approve_day)
    @wktime = Wktime.find_or_create_by_user_id_and_project_id_and_begin_date(user_id:params[:user_id],project_id:project.id,begin_date: approve_day)
    @wktime.submitted_on = Date.today
    @wktime.submitter_id = User.current.id
    @wktime.hours = @sum
    @wktime.statusupdater_id = User.current.id
    if params[:wktime_approve].present? && @wktime.status !="l2" && @wktime.status !="l3"
      @wktime.pre_status=@wktime.status
      @wktime.status = 'l1'
      @wktime.project_id = project.id
    elsif params[:wktime_unapprove].present? && @wktime.status !="l2" && @wktime.status !="l3"
      @wktime.pre_status=@wktime.status
      @wktime.status = 'n'
      @wktime.project_id = project.id
    elsif  params[:wktime_reject].present? && @wktime.status != "l2" && @wktime.status !="l3"
      Rejection.create(:user_id => params[:user_id], :project_id => project.id, :rejected_by =>User.current.id, :rejected_role=> 'l1', :comment =>params[:wktime_notes], :date => @wktime.begin_date )
      @wktime.pre_status=@wktime.status
      @wktime.status = 'r'
      @wktime.project_id = project.id
    end
  end


  def update_l1_or_l2_record(params, approve_day, project, role)
    #@wktime = Wktime.find_or_initialize_by_begin_date_and_user_id(:user_id=>params[:user_id],:begin_date=>approve_day.to_date)
    #    Wktime.where(:user_id=>params[:user_id],:begin_date=>approve_day.to_date,:hours=>@sum, :project_id => project.id).first_or_initialize

    @wktime = Wktime.find_or_create_by_user_id_and_project_id_and_begin_date(user_id:params[:user_id],project_id:project.id,begin_date: approve_day)

    if params[:wktime_approve].present? && @wktime.status != "l3"
      if role == "l2"
        @wktime.pre_status=@wktime.status
        @wktime.status = role
      end
    elsif params[:wktime_unapprove].present? && @wktime.status != "l3"
      if @wktime.pre_status.present? && @wktime.pre_status.to_s != role.to_s
        @wktime.status = @wktime.pre_status
      else
        @wktime.status = 'n'
      end
    elsif  params[:wktime_reject].present? && @wktime.status !="l3"
      @wktime.pre_status=@wktime.status
      @wktime.status = 'r'
      Rejection.create(:user_id => params[:user_id], :project_id => project.id, :rejected_by =>User.current.id, :rejected_role=> 'l2', :comment =>params[:wktime_notes], :date => @wktime.begin_date )
    end
    @wktime.project_id = project.id
    @sum = @sum.present? ? @sum : 0
    @wktime.hours = @sum
  end

  # L3 approval

  def findWkTE_l3(start_date, end_date)
    #setup
    cond = getCondition('begin_date', @user.nil? ? nil : @user.id, start_date, end_date)
    findWkTEByCond(cond)
    @wktime = @wktimes[0] unless @wktimes.blank?
  end


end