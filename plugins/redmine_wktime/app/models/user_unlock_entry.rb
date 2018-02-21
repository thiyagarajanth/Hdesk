class UserUnlockEntry < ActiveRecord::Base
  unloadable
  belongs_to :user
  validates_presence_of :user_id, :comment

  def self.user_lock_status(user_id)
    days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
    current_time = Time.now
    expire_time = Time.new(current_time.year, current_time.month, current_time.day,setting_hr,setting_min,1, "+05:30")
    deadline_date = (Date.today-days.to_i)
    lock_status = UserUnlockEntry.where(:user_id=>user_id)
    if lock_status.present?
      lock_status_expire_time = lock_status.last.expire_time.to_datetime
      if lock_status_expire_time <= expire_time
        lock_status.delete_all
      end
    end
    user = User.where(:id=> user_id)
    rec = TimeEntry.where(:user_id=> user_id, :spent_on => (deadline_date-1).strftime('%Y-%m-%d').to_s)
    @rec_status=''
    date = deadline_date-1
    (1..30).each do |x|
      @rec=TimeEntry.where(:user_id=> user_id, :spent_on => date.to_date)
      if !@rec.present?
        @rec_status=[]
        break
      else
        @rec_status='true'
        date -=1
      end
    end

    #&& user.last.created_on.to_date < (deadline_date-1)
    if expire_time > current_time
      if !@rec_status.present? && !lock_status.present?
        return true
      elsif !@rec_status.present? && lock_status.present?
        #lock_status.delete_all
        return false
      else
        return false
      end
    elsif expire_time <= current_time
      if !@rec_status.present? && !lock_status.present?
        return true
      elsif !@rec_status.present? && lock_status.present? && (lock_status_expire_time.to_date <= expire_time.to_date)

        #lock_status.delete_all
        return true
      else
        #lock_status.delete_all
        return false

      end
    end

  end


  def self.lock_status(user_id)
    lock_status = UserUnlockEntry.where(:user_id=>user_id)
    if lock_status.present?
      return true
    end

  end

  def self.dead_line_date
    array_days = []
    days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")

    dead_line_date = (current_time.to_date)
    collect_dates=[]
    #  if expire_time < current_time
    #    p "++++before enter ++dead_line_date++"
    #    p dead_line_date
    # dead_line_date = dead_line_date - 1
    #  end
    cureent_user_timezone = (User.current.time_zone.present? && User.current.time_zone.name.present?) ? User.current.time_zone.name.to_s.delete(' ') : "Chennai"
    if Setting.plugin_redmine_wktime['wktime_public_holiday'].present?
      Setting.plugin_redmine_wktime['wktime_public_holiday'].each do |public_holiday|
        if public_holiday.delete(' ').include?(cureent_user_timezone)
          collect_dates << public_holiday.split('|')[0].strip
        end
      end
      i = 30
      dead_line_date = dead_line_date+1
      while i > 0 do
        dead_line_date -= 1
        break if (!(dead_line_date.to_date.wday ==6) && !(dead_line_date.to_date.wday ==0)) && (!collect_dates.include?(dead_line_date.to_s.strip))
      end

      #break if (!collect_dates.include?(dead_line_date.to_s.strip) && (!(dead_line_date.to_date.wday ==6) && !(dead_line_date.to_date.wday ==0)))
      dead_line_date = get_final_dead_line(dead_line_date)
    end
    return dead_line_date
  end

  def self.get_final_dead_line(dead_line_date)
    days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    dead_line_date = dead_line_date - days

    setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")
    if current_time > expire_time
      dead_line_date = dead_line_date - 1

    end

    setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")
    collect_dates=[]
    if Setting.plugin_redmine_wktime['wktime_public_holiday'].present?
      Setting.plugin_redmine_wktime['wktime_public_holiday'].each do |public_holiday|
        cureent_user_timezone = (User.current.time_zone.present? && User.current.time_zone.name.present?) ? User.current.time_zone.name.to_s.delete(' ') : "Chennai"

        if public_holiday.delete(' ').include?(cureent_user_timezone)
          collect_dates << public_holiday.split('|')[0].strip
        end
      end
      i = 30
      dead_line_date = dead_line_date+1
      while i > 0 do
        dead_line_date -= 1
        break if (!(dead_line_date.to_date.wday ==6) && !(dead_line_date.to_date.wday ==0)) && (!collect_dates.include?(dead_line_date.to_s.strip))
      end

    end
    return dead_line_date
  end

  def self.dead_line_final_method
    array_days = []
    days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    collect_dates=[]
    if Setting.plugin_redmine_wktime['wktime_public_holiday'].present?
      cureent_user_timezone = (User.current.time_zone.present? && User.current.time_zone.name.present?) ? User.current.time_zone.name.to_s.delete(' ') : "Chennai"
      Setting.plugin_redmine_wktime['wktime_public_holiday'].each do |public_holiday|
        if public_holiday.delete(' ').include?(cureent_user_timezone)
          collect_dates << public_holiday.split('|')[0].strip
        end
      end
    end
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    dead_line = (current_time.to_date)
    array_size = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    i = 0
    while i <= array_size.to_i do
      if check_public(dead_line)
        array_size +=1
        dead_line = (dead_line-1)
      else
        array_days << dead_line
        dead_line = (dead_line-1)
      end
      break if array_days.size > Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
      i += 1
    end
    if array_days.present?
      return array_days.last
    end
  end

  def self.dead_line_for_lock(current_time)
    array_days = []
    dead_line = (current_time.to_date + 1.day )

    while check_public(dead_line) == true do
      dead_line +=1
   end
    return dead_line
  end



  def self.check_public(dead_line)
    collect_dates=[]
    if Setting.plugin_redmine_wktime['wktime_public_holiday'].present?
      cureent_user_timezone = (User.current.time_zone.present? && User.current.time_zone.name.present?) ? User.current.time_zone.name.to_s.delete(' ') : "Chennai"
      Setting.plugin_redmine_wktime['wktime_public_holiday'].each do |public_holiday|
        if public_holiday.delete(' ').include?(cureent_user_timezone)
          collect_dates << public_holiday.split('|')[0].strip
        end
      end
    end
    if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && collect_dates.present? && collect_dates.include?(dead_line.to_s.strip) || (dead_line.to_date.wday == 6) || (dead_line.to_date.wday == 0)
      return true
    end

  end


  def self.dead_line
    array_days = []
    days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    dead_line = (current_time.to_date-days.to_i)
    array_size = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    i = 0
    while i < array_size.to_i do
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(dead_line.to_date.strftime('%Y-%m-%d').to_s) || (dead_line.to_date.wday == 6) || (dead_line.to_date.wday == 0)
        array_size +=1
        dead_line = (dead_line-1)
      else
        array_days << dead_line
        if array_days.size < Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
          array_size +=1
          dead_line = (dead_line-1)
        end
      end
      i += 1
    end
    if array_days.present?
      return array_days.last
    end
  end



  def self.edit_user(user,entry)
    rec_l1 = Wktime.where(:user_id => entry.user_id,:begin_date => entry.spent_on.to_date,:status => 'l1')
    rec_l2 = Wktime.where(:user_id => entry.user_id,:begin_date => entry.spent_on.to_date, :status => 'l2' )
    rec_l3 = Wktime.where(:user_id => entry.user_id,:begin_date => entry.spent_on.to_date, :status => 'l3' )

    if rec_l1.present? || rec_l2.present? || rec_l3.present?
      return true
    else
      return false
    end
  end


end