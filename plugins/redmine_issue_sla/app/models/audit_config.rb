class AuditConfig < ActiveRecord::Base
  serialize :field_name
  serialize :old_value
  serialize :new_value
  serialize :updated_value, JSON


  def my_titleize(str)
    str.gsub('_', ' ').capitalize
  end

  def week_days(day)
    case day
      when 'sun'
        'Sunday'
      when 'mon'
        'Monday'
      when 'tue'
        'Tuesday'
      when 'wed'
        'Wednesday'
      when 'thu'
        'Thursday'
      when 'fri'
        'Friday'
      when 'sat'
        'Saturday'
      else
        false
    end
  end

  def get_status_value(value)
    value == "true" ? "Active" : (value == "false" ?  "Inactive" : value)
  end
end