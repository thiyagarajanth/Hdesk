module WktimeControllerPatch
  def self.included(base)
    base.class_eval do
      include WktimeHelper

      before_filter :require_login
      before_filter :check_perm_and_redirect, :only => [:edit, :update]
      before_filter :check_editperm_redirect, :only => [:destroy]
      before_filter :check_view_redirect, :only => [:index]
      before_filter :check_log_time_redirect, :only => [:new]

      accept_api_auth :index, :edit, :update, :destroy, :deleteEntries

      helper :custom_fields

      # Insert overrides here, for example:
      def update
        Rails.logger.info "++++update page "
        start_time = Time.now
        setup
        not_met_ids = params[:not_met_issue_ids]
        if not_met_ids.present?
          not_met_ids.each_with_index do |id, i|
            detail =   IssueDetail.find_or_initialize_by_issue_id(id)
            detail.remarks = params[:sla_reasons][i]
            detail.save
          end
        end
        set_loggable_projects
        @wktime = nil
        errorMsg = nil
        @error_msg_id = []
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
                  @error_msg_id = updateEntryError(entry) if allowSave

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
              # p errorMsg, @error_msg_id
              # raise
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

      def updateEntryError(entry)
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
              @error_msg_id << {:id => entry.issue_id, :msg => errorMsg}
            end
          else
            errorMsg = l(:error_not_permitted_save)
          end
        end
        return @error_msg_id
      end

    end
  end
end
