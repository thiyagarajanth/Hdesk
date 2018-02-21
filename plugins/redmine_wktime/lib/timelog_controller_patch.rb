module TimelogControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      before_filter :find_time_entry, :only => [:show, :edit, :update]
      before_filter :authorize, :except => [:new, :index, :report,:edit,:update]
      before_filter :find_time_entries, :only => [:bulk_edit, :bulk_update, :destroy]
      before_filter :authorize, :only => [:show, :edit, :update, :bulk_edit, :bulk_update, :destroy]
      before_filter :find_optional_project, :only => [:new, :create, :index, :report]
      before_filter :authorize_global, :only => [:new, :create, :index, :report]
      def create
        start_time = Time.now
        @time_entry ||= TimeEntry.new(:project => @project, :issue => @issue, :user => User.current, :spent_on => User.current.today)
        @time_entry.safe_attributes = params[:time_entry]
        log_status = call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })
        wktime_helper = Object.new.extend(WktimeHelper)
        status = wktime_helper.getTimeEntryStatus((params[:time_entry][:spent_on]).to_date,User.current.id)
        wiki_status_l1 = Wktime.where(:user_id=>User.current.id,:begin_date=>params[:time_entry][:spent_on],:status =>"l1" )
        wiki_status_l2 = Wktime.where(:user_id=>User.current.id,:begin_date=>params[:time_entry][:spent_on],:status =>"l2" )
        wiki_status_l3 = Wktime.where(:user_id=>User.current.id,:begin_date=>params[:time_entry][:spent_on],:status =>"l3" )
        log_time_status = check_time_log_entry(params[:time_entry][:spent_on],User.current)
        if log_time_status == true && !log_status.compact.present? && @time_entry.save
          respond_to do |format|
            format.html {
              flash[:notice] = l(:notice_successful_create)
              if params[:continue]
                if params[:project_id]
                  options = {
                      :time_entry => {:issue_id => @time_entry.issue_id, :activity_id => @time_entry.activity_id},
                      :back_url => params[:back_url]
                  }
                  if @time_entry.issue
                    redirect_to new_project_issue_time_entry_path(@time_entry.project, @time_entry.issue, options)
                  else
                    redirect_to new_project_time_entry_path(@time_entry.project, options)
                  end
                else
                  options = {
                      :time_entry => {:project_id => @time_entry.project_id, :issue_id => @time_entry.issue_id, :activity_id => @time_entry.activity_id},
                      :back_url => params[:back_url]
                  }
                  redirect_to new_time_entry_path(options)
                end
              else
                redirect_back_or_default project_time_entries_path(@time_entry.project)
              end
            }
            format.api  { render :action => 'show', :status => :created, :location => time_entry_url(@time_entry) }
          end
        else

          if status.to_s != 's' && log_time_status == false
            if wiki_status_l1.present? || wiki_status_l2.present? || wiki_status_l3.present?
              @time_entry.errors.add(:Note,'Your log time approved,Please contact your manger to log a time.')
            else
              @time_entry.errors.add(:Note,'Your log time was locked,Please contact your manger to log a time.')
            end
            #@time_entry.errors.add(:Note,'Your log time was locked,Please contact your manger to log a time.')

          end
          # @time_entry.errors.add(:Note,'Please contact your manger to log a time.')
          respond_to do |format|
            format.html { render :action => 'new' }
            format.api  { render_validation_errors(@time_entry) }
          end
        end

        Rails.logger.info "++++elapsed time raja+++++++++++"
Rails.logger.info "Time elapsed #{(Time.now - start_time)*1000} milliseconds"
Rails.logger.info "++++End +++++++"
      end
      #alias_method_chain :show, :plugin # This tells Redmine to allow me to extend show by letting me call it via "show_without_plugin" above.
      # I can outright override it by just calling it "def show", at which case the original controller's method will be overridden instead of extended.

      def edit
        @time_entry.safe_attributes = params[:time_entry]
      end
      def update
        @time_entry.safe_attributes = params[:time_entry]
        log_status = call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })
        wktime_helper = Object.new.extend(WktimeHelper)
        status = wktime_helper.getTimeEntryStatus((params[:time_entry][:spent_on]).to_date,User.current.id)
        log_time_status = check_time_log_entry(params[:time_entry][:spent_on],User.current)
        if log_time_status == true && !log_status.compact.present? && @time_entry.save
          respond_to do |format|
            format.html {
              flash[:notice] = l(:notice_successful_update)
              redirect_back_or_default project_time_entries_path(@time_entry.project)
            }
            format.api  { render_api_ok }
          end
        else
          if status.to_s != 's' && log_time_status == false
            @time_entry.errors.add(:Note,'Your log time was locked,Please contact your manger to log a time.')
          end
          respond_to do |format|
            format.html { render :action => 'edit' }
            format.api  { render_validation_errors(@time_entry) }
          end
        end
      end
      private
      def find_time_entry
        @time_entry = TimeEntry.find(params[:id])
        if UserUnlockEntry.edit_user(User.current,@time_entry) == true
          render_403
          return false
        end
        @project = @time_entry.project
      rescue ActiveRecord::RecordNotFound
        render_404
      end
    end
  end

  def check_time_log_entry(select_time,current_user)
    days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
     #current_time = Time.now
     #expire_time = Time.new(current_time.year, current_time.month, current_time.day,setting_hr,setting_min,1, "+05:30")

    wktime_helper = Object.new.extend(WktimeHelper)

    current_time = wktime_helper.set_time_zone(Time.now)
    expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")
    deadline_date = (current_time.to_date-days.to_i).strftime('%Y-%m-%d').to_date
    deadline_date = UserUnlockEntry.dead_line_final_method
    if deadline_date.present?
      #date = date - days.to_i
      deadline_date = deadline_date.to_date.strftime('%Y-%m-%d').to_date
    end
    lock_status = UserUnlockEntry.where(:user_id=>current_user.id)
    if lock_status.present?
      lock_status_expire_time = lock_status.last.expire_time
      if lock_status_expire_time.to_date <= expire_time.to_date
        lock_status.delete_all
      end
    end
    entry_status =  TimeEntry.where(:user_id=>current_user.id,:spent_on=>select_time.to_date.strftime('%Y-%m-%d').to_date)
    wiki_status_l1=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l1")
    wiki_status_l2=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l2")
    wiki_status_l3=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l3")
    #lock_status = UserUnlockEntry.where(:user_id=>current_user.id)
    permanent_unlock = PermanentUnlock.where(:user_id=>current_user.id)
    if ((select_time.to_date > deadline_date.to_date || lock_status.present?) || ( permanent_unlock.present? && permanent_unlock.last.status == true)) && (!wiki_status_l1.present? && !wiki_status_l2.present? && !wiki_status_l3.present?)

      return true

    elsif ((select_time.to_date == deadline_date.to_date && expire_time > current_time) || lock_status.present? || (permanent_unlock.present? && permanent_unlock.last.status == true)) && ((!wiki_status_l1.present? && !wiki_status_l2.present? && !wiki_status_l3.present?))

      return true
    else

      return false
    end

  end
end