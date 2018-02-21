module SlaTimeHelper

  def get_current_user_approver_role(issue, user_id)
    level = []
    roles = issue.inia_project.approval_role_users.where( :project_id => issue.project_id)
    roles.each{|rec|
      rata = rec.approval_role.ticket_approvals.where(:ticket_tag_id => issue.ticket_tag.id).first rescue nil
      if ((rec.user_id rescue nil)== user_id || ((rata.present? && rata.child.present?) && rata.child.user_id == user_id))
        level << [rec.approval_role.level, rec.approval_role.id ] if rec.approval_role.present?
      end
    }.compact
    level.present? ? level.max : 0
  end

  def get_approver_sla(issue)
    approval_status =  IssueSlaStatus.where(:project_id => issue.project.id, :tracker_id => issue.tracker.id, :approval_sla => true).map(&:issue_status_id)
    # taf = issue.ticket_approval_flows(:user_id => issue.assigned_to).last.ticket_approval rescue nil
    # ari = taf.approval_role_id.present? ? taf.approval_role_id : taf.parent.approval_role_id
    cur_role =  get_current_user_approver_role(issue, issue.assigned_to_id)
    approverSla = issue.project.approver_slas.where(:approval_role_id => cur_role[1], :tracker_id => issue.tracker_id, :priority_id => issue.priority_id).last.estimated_time rescue nil
    estimated_hours =  approverSla.present? ? approverSla : "0.0"
    minute = estimated_hours.to_s.split(/\./).last
    total = ((estimated_hours.to_s.split(/\./).first.to_i * 100) + minute.to_i)
    if approval_status.include? issue.status_id
      times = issue.ticket_approval_flows.where(:user_id => issue.assigned_to_id).map(&:waiting_time)
      spare_time = return_sla_duration(issue)
      test = 0
      times.each do |time|
        time = time.present? ? time : '0'
        if time.include?('-')
          tot = time.tr('-','').split('.')
          test = tot.first.to_i*100 + tot.first.to_i +  spare_time.to_i
          @sym = '-'
        else
          tot = time.split('.')
          thm = tot.first.to_i*100 + tot.first.to_i + spare_time.to_i
          test =   total - thm
          @sym = total < thm ? '- ' : ''
        end
      end
      hhmm = test.abs.divmod(100)
      hh = hhmm.first
      mm = hhmm.last
    else
      @sym = total > -1 ? '' : '- '
      hh,mm = total.abs.divmod(100)
    end
    min = mm.to_s.size == 1 ? "0#{mm}" : mm
    "#{@sym}#{hh}.#{min.to_i*60/100}"
  end

  def duration_of_ticket(issue_id, issue_status, old_status)
    issue = Issue.find issue_id
    tracker_status =  IssueSlaStatus.where(:project_id => issue.project.id, :tracker_id => issue.tracker.id)
    current_status = tracker_status.find_by_issue_status_id(issue.status_id)
    duration = (current_status.present? && current_status.sla_timer == 'start') ? return_sla_duration(issue) : 0
    if  issue_status.present?
      s  = IssueStatus.find(issue_status)
      sla_id = tracker_status.find_by_issue_status_id(s.id)
      issue.sla_times.create(:issue_sla_status_id => sla_id.id,:user_id => issue.assigned_to_id,  :old_status_id =>(old_status.to_i), :pre_status_duration => duration )
    end
  end

  def get_resolved_duration(issue)
    resolved = IssueStatus.find_by_name('Resolved').id
    rec = Journal.find_by_sql("select created_on, Minute(TIMEDIFF(NOW(),created_on))as min from journals as j, journal_details as jd where journalized_id='#{issue.id}' and jd.journal_id=j.id and jd.prop_key='status_id' and value=#{resolved}")[0]
    st = rec.created_on.to_date
    ed = Date.today
    count = 0
    (st..ed).each_with_index do |day, i|
      count = count + 1 if !check_holiday(day, issue)
    end
    timediff = (Time.now - rec.created_on).to_i
    response = ResponseSla.find_by_tracker_id_and_project_id(issue.tracker_id, issue.project_id)
    base =  (response.ticket_closing.to_i * 24 * 60 * 60).to_i
    leave = (count* 24 * 60 * 60).to_i
    res = base - (timediff - leave)
    res < 0
  end

  def return_sla_duration(issue)
    tracker_sla_day =  SlaWorkingDay.where(:project_id => issue.project.id, :tracker_id => issue.tracker.id).last
    f_hr = tracker_sla_day.start_at.split(/\:/).first.to_i
    f_min = tracker_sla_day.start_at.split(/\:/).last.to_i
    e_hr = tracker_sla_day.end_at.split(/\:/).first.to_i
    e_min = tracker_sla_day.end_at.split(/\:/).last.to_i
    bf_hr = tracker_sla_day.break_from.split(/\:/).first.to_i
    bf_min = tracker_sla_day.break_from.split(/\:/).last.to_i
    bt_hr = tracker_sla_day.break_to.split(/\:/).first.to_i
    bt_min = tracker_sla_day.break_to.split(/\:/).last.to_i
    t = Time.now
    slas = issue.sla_times
    issue_cr_time =  issue.created_on.to_time.localtime
    time_now = Time.now.localtime
    from_time = Time.local(t.year, t.month, t.day, f_hr, f_min)
    to_time = Time.local(t.year, t.month, t.day, e_hr, e_min)
    break_from = Time.local(t.year, t.month, t.day, bf_hr, bf_min)
    break_to = Time.local(t.year, t.month, t.day, bt_hr, bt_min)
    btn_wrk = time_now >= from_time && time_now <= to_time
    btn_break = time_now >= break_from && time_now <= break_to
    non_working_ticket = (issue_cr_time > to_time || issue_cr_time < from_time) && !btn_wrk
    ssd = slas.last.created_at.to_date if slas.present?
    isd = issue.created_on.to_date
    ed = Date.today
    total_dur = []

    if isd != ed && slas.count == 0
      (isd..ed).each{ |date|
        if check_holiday(date, issue)
          f_time = Time.local(date.year, date.month, date.day, f_hr, f_min)
          t_time = Time.local(date.year, date.month, date.day, e_hr, e_min)
          bf_time = Time.local(date.year,date.month,date.day, bf_hr, bf_min)
          bt_time = Time.local(date.year,date.month,date.day,bt_hr,bt_min)
          now_time = date==Date.today ? Time.now : date.to_time.end_of_day
          total_dur << today_new_sla_update(issue_cr_time, f_time, t_time,bf_time,bt_time, now_time)
        end
      }
      duration = total_dur.sum
    elsif slas.count != 0 && ssd != ed
      (ssd..ed).each{ |date|
        if check_holiday(date, issue)
          f_time = Time.local(date.year, date.month, date.day, f_hr, f_min)
          t_time = Time.local(date.year, date.month, date.day, e_hr, e_min)
          bf_time = Time.local(date.year,date.month,date.day, bf_hr, bf_min)
          bt_time = Time.local(date.year,date.month,date.day,bt_hr,bt_min)
          now_time = date==Date.today ? Time.now : date.to_time.end_of_day
          sla_time = issue.sla_times.last.created_at.localtime
          total_dur << today_new_sla_update(sla_time, f_time, t_time,bf_time,bt_time, now_time)
        end
      }
      duration = total_dur.sum
    elsif !non_working_ticket && slas.count == 0
      duration =  today_new_sla_update(issue_cr_time, from_time,to_time,break_from,break_to,time_now)
    elsif !non_working_ticket && slas.count > 0
      sd = slas.last.created_at.to_date
      ed = Date.today
      if sd != ed
        total_dur = []
        (sd..ed).each{ |date|
          if check_holiday(date, issue)
            f_time = Time.local(date.year, date.month, date.day, f_hr, f_min)
            t_time = Time.local(date.year, date.month, date.day, e_hr, e_min)
            bf_time = Time.local(date.year,date.month,date.day, bf_hr, bf_min)
            bt_time = Time.local(date.year,date.month,date.day,bt_hr,bt_min)
            now_time = date==Date.today ? Time.now : date.to_time.end_of_day
            sla_time = issue.sla_times.last.created_at.localtime
            total_dur << today_new_sla_update(sla_time, f_time, t_time,bf_time,bt_time, now_time)
          end
        }
        duration = total_dur.sum
      else
        sla_time = issue.sla_times.last.created_at.localtime
        p duration =  today_new_sla_update(sla_time, from_time, to_time,break_from,break_to, time_now)
      end
    elsif slas.count == 0 && issue_cr_time < from_time && time_now > to_time
       duration =(((to_time - break_to)+(break_from - from_time))/60).to_i
      #duration = ((to_time - from_time) / 60).to_i
    elsif non_working_ticket || (slas.present? && issue.sla_times.last.created_at.localtime > to_time)
      duration = 0
    end
    duration * 100 /60
  end

  def today_new_sla_update(issue_cr_time, from_time, to_time,break_from_time,break_to_time, time_now)

    case true
      when issue_cr_time > from_time && time_now < break_from_time && issue_cr_time < break_from_time
        duration = ((time_now - issue_cr_time)/60).to_i
      when issue_cr_time > from_time && (break_from_time..break_to_time).cover?(time_now) && !(break_from_time..break_to_time).cover?(issue_cr_time)
        duration = ((break_from_time - issue_cr_time)/60).to_i
      when issue_cr_time > from_time && (break_to_time..to_time).cover?(time_now) && issue_cr_time < break_from_time
        duration = (((time_now - break_to_time)+(break_from_time - issue_cr_time))/60).to_i
      #p duration = ((time_now - break_to_time)/60).to_i
      when issue_cr_time > from_time && time_now > to_time && issue_cr_time < break_from_time
        duration = (((to_time - break_to_time)+(break_from_time - issue_cr_time))/60).to_i
      # p duration = ((to_time - sla_time)/60).to_i
      when (break_from_time..break_to_time).cover?(time_now) && (break_from_time..break_to_time).cover?(issue_cr_time)
        duration = 0
      when (break_from_time..break_to_time).cover?(issue_cr_time) && (break_to_time..to_time).cover?(time_now)
        duration = ((time_now - break_to_time)/60).to_i
      when (break_from_time..break_to_time).cover?(issue_cr_time) && time_now > to_time
        duration = ((to_time - break_to_time)/60).to_i
      when (break_to_time..to_time).cover?(issue_cr_time) && time_now > to_time
        duration = ((to_time - issue_cr_time)/60).to_i
      when (break_to_time..to_time).cover?(issue_cr_time) && (break_to_time..to_time).cover?(time_now)
        duration =((time_now - issue_cr_time)/60).to_i
      when issue_cr_time < from_time && time_now < break_from_time
        duration = ((time_now-from_time)/60).to_i
      when issue_cr_time < from_time && (break_from_time..break_to_time).cover?(time_now)
        duration = ((break_from_time - from_time)/60).to_i
      when issue_cr_time < from_time && (break_to_time..to_time).cover?(time_now)
        duration = (((time_now - break_to_time)+(break_from_time - from_time))/60).to_i
      when issue_cr_time < from_time && time_now > to_time
        duration = (((to_time - break_to_time)+(break_from_time - from_time))/60).to_i
      when issue_cr_time < from_time && from_time > time_now || issue_cr_time > to_time
        duration = 0
      else
      end

    return duration
  end

  # Add auto TimeEntry comments
  def retun_time_entry_msg(slatime)
    new_status = slatime.issue_sla_status.issue_status.name
    pre_status = slatime.old_status.issue_status.name #unless slatime.count == 1
    pre_status = pre_status == new_status ? 'New' : pre_status
    "Status was changed from #{pre_status} to #{new_status}"
  end

  # Should return within working hours or not
  def check_sla_hours(issue)
    tracker_sla_day =  SlaWorkingDay.where(:project_id => issue.project.id, :tracker_id => issue.tracker.id).last
    s_from = Time.parse(tracker_sla_day.start_at)
    e_to = Time.parse(tracker_sla_day.end_at)
    t = Time.now
    Time.local(t.year, t.month, t.day, s_from.hour, s_from.min) <= Time.now && Time.local(t.year, t.month, t.day, e_to.hour, e_to.min) >= Time.now
  end

  # It will return SLA pending time to show page
  def sla_time_count(issue)
    if redmine_issue_sla_enabled(issue)
      total = 0
      if issue.estimated_hours.present?
        minute = issue.estimated_hours.to_s.split(/\./).last
        estimated_hours =  issue.estimated_hours.present? ? issue.estimated_hours : 0.0
        first = ((estimated_hours.to_s.split(/\./).first.to_i * 100) + minute.to_i)
        time_entries = (issue.time_entries.sum('hours').to_f * 100).to_i
        # if time_entries > 0
        #   p '==== res'
        #   p  total = first - time_entries
        # else
        total = first - issue.sla_times.sum('pre_status_duration').to_i
        #end
      end
      tracker_status =  IssueSlaStatus.where(:project_id => issue.project.id, :tracker_id => issue.tracker.id)
      current_status = tracker_status.find_by_issue_status_id(issue.status_id).present? ? tracker_status.find_by_issue_status_id(issue.status_id).sla_timer : ''
      if current_status == 'start' # && today_holiday?(issue) #&& check_sla_hours(issue)
        spare_time = return_sla_duration(issue)
        test =   total - spare_time.to_i
        hh,mm = test.abs.divmod(100)
        @sym = test > -1 ? '' : '- '
      else
        @sym = total > -1 ? '' : '- '
        hh,mm = total.abs.divmod(100)
      end
      min = mm.to_s.size == 1 ? "0#{mm}" : mm
      mm = min.to_i*60/100
      min = mm.to_s.size == 1 ? "0#{mm}" : mm
      p '===============this ine-------------------'
     p total_dur = "#{@sym}#{hh}.#{min}"
    else
      p '=================else-------------------'
      p total_dur =   issue.estimated_hours
    end

    return total_dur
  end

  def get_spent_time(time, issue)
    hh,mm = (time.to_s.present? && time.to_s.include?('.')) ? (time.to_s.split('.') rescue ["0", "0"]) : ["0", "0"]
    hm = (hh.tr('-','').to_i * 100) + mm.to_i*100/60
    if time.to_s.include?('-')
      total = (issue.estimated_hours.to_i * 100) + hm
    else
      total =  (issue.estimated_hours.to_i * 100) - hm
    end
    hh, mm = total.abs.divmod(100)
    min = mm.to_s.size == 1 ? "0#{mm}" : mm
    mm = (min.to_i*60)/100
    min = mm.to_s.size == 1 ? "0#{mm}" : mm
    total.present? ? "#{hh}.#{min}" : nil
  end

  def time_fomrmat(time)
    p '=======time========'
    p time
    hh,mm = time.present? ? (time.to_s.split('.') rescue ["0", "0"]) : ["0", "0"]
    mm = mm[0,2]
    mm = mm.to_s.size == 1 ? "#{mm}0" : mm
    mm = (mm.to_i * 60 / 100).to_i
    p mm = mm.to_s.size == 1 ? "0#{mm}" : mm
    "#{hh}.#{mm}".to_f
  end

  # make sure today is holiday or not
  def today_holiday?(issue)
    day = Date.today
    check_holiday(day, issue)
  end

  def check_holiday(holiday, issue)
    public_holiday = issue.project.enabled_modules.map(&:name).include?('redmine_wktime') ? Setting.plugin_redmine_wktime['wktime_public_holiday'] : []
    tracker_sla_day =  SlaWorkingDay.where(:project_id => issue.project.id, :tracker_id => issue.tracker.id).last
    if tracker_sla_day.present?
      if holiday.wday == 0 && tracker_sla_day.sun == false
        false
      elsif holiday.wday == 1 && tracker_sla_day.mon == false
        false
      elsif holiday.wday == 2 && tracker_sla_day.tue == false
        false
      elsif holiday.wday == 3 && tracker_sla_day.wed == false
        false
      elsif holiday.wday == 4 && tracker_sla_day.thu == false
        false
      elsif holiday.wday == 5 && tracker_sla_day.fri == false
        false
      elsif holiday.wday == 6 && tracker_sla_day.sun == false
        false
      elsif public_holiday.present? && public_holiday.include?(holiday.to_date.strftime('%Y-%m-%d').to_s)
        false
      else
        true
      end
    else
      false
    end
  end

  # To check the project permission list. based on this result response button will shown to user
  def check_project_permission(ids, l)
    projects = Project.find(ids)
    members = []
    permissions = []
    projects.each { |rec| members << rec.member_principals.find_by_user_id(User.current.id)  }
    members.flatten.each do |rec|
      rec.member_roles.each { |rec| permissions << rec.role.permissions } if rec.present?
    end
    if permissions.flatten.present? && permissions.flatten.include?(l.to_sym)
      return true
    else
      return false
    end
  end


  # Check if current project has enabled SLA plugin or not
  def redmine_issue_sla_enabled(issue)
    issue.project.enabled_modules.map(&:name).include?('redmine_issue_sla')
  end

  def auto_closing
    closed = IssueStatus.find_by_name('Closed').id rescue ''
    resolved = IssueStatus.find_by_name('Resolved').id rescue ''
    issues = Issue.where(:status_id => resolved)
    issues.each do |issue|
      state = get_auto_close_duration(issue)
      if state
        admin =  User.find_by_login('admin')
        message = "Thank you for giving us this opportunity to facilitate you. However due to the non-closure of the resolved ticket, please note that this ticket has been auto closed by NANBA."
        issue.init_journal(User.find(admin),message )
        issue.status_id = closed
        issue.save
        rate = UserRating.find_or_initialize_by_issue_id(issue.id)
        rate.project_id = issue.project_id
        user_id = Journal.find_by_sql("select user_id from journals as j
                  join journal_details as jd on j.id=jd.journal_id and j.journalized_id=#{issue.id} and
                  jd.prop_key='status_id' and jd.value=(select id from issue_statuses
                  where name='Resolved')").map(&:user_id).last
        rate.rated_for = user_id
        rate.rated_by = issue.author_id
        rate.rating = 5
        rate.save
      end
    end
  end

  def get_auto_close_duration(issue)
    response = ResponseSla.find_by_tracker_id_and_project_id(issue.tracker_id, issue.project_id)
    if response.auto_close.present? && response.auto_close > 0
      resolved = IssueStatus.find_by_name('Resolved').id
      rec = Journal.find_by_sql("select created_on, Minute(TIMEDIFF(NOW(),created_on))as min from journals as j, journal_details as jd where journalized_id='#{issue.id}' and jd.journal_id=j.id and jd.prop_key='status_id' and value=#{resolved}").last
      st = rec.created_on.to_date
      ed = Date.today
      count = 0
      (st..ed).each_with_index do |day, i|
        count = count + 1 if !check_holiday(day, issue)
      end
      timediff = (Time.now - rec.created_on).to_i
      base =  (response.auto_close.to_i * 24 * 60 * 60).to_i
      leave = (count* 24 * 60 * 60).to_i
      res = base - (timediff - leave)
      res < 0
    else
      false
    end
  end
end