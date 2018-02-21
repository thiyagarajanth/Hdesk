module WktimeHelper
  include Redmine::Export::PDF
  include Redmine::Utils::DateCalculation
  require 'nokogiri'

  def options_for_period_select(value)
    options_for_select([[l(:label_all_time), 'all'],
                        [l(:label_this_week), 'current_week'],
                        [l(:label_last_week), 'last_week'],
                        [l(:label_this_month), 'current_month'],
                        [l(:label_last_month), 'last_month'],
                        [l(:label_this_year), 'current_year']],
                       value.blank? ? 'current_month' : value)
  end

  def options_wk_status_select(value)
    options_for_select([[l(:label_all), 'all'],
                        [l(:wk_status_new), 'n'],
                        [l(:wk_status_submitted), 's'],
                        [l(:wk_status_approved), 'a'],
                        [l(:wk_status_rejected), 'r']],
                       value.blank? ? 'all' : value)
  end

  def statusString(status)

    statusStr = l(:wk_status_new)
    case status
      when 'a'
        statusStr = l(:wk_status_approved)
      when 'r'
        statusStr = l(:wk_status_rejected)
      when 's'
        statusStr = l(:wk_status_submitted)
      else
        statusStr = l(:wk_status_new)
    end
    return statusStr
  end

  def statusEntry(entry,user_id)
    startday = entry.spent_on.to_date
    end_day = (startday + 6)
    work_days = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)

      else
        work_days << day
      end
    end
    #end_day = (startday + 6)
    status_l1 = Wktime.where(begin_date: startday.to_date..end_day.to_date,status: "l1",user_id: entry.user_id)
    status_l2 = Wktime.where(begin_date: startday.to_date..end_day.to_date,status: "l2",user_id: entry.user_id)
    status_l3 = Wktime.where(begin_date: startday.to_date..end_day.to_date,status: "l3",user_id: entry.user_id)
    status_n = Wktime.where(begin_date: startday.to_date..end_day.to_date,status: "n",user_id: entry.user_id)
    status_r = Wktime.where(begin_date: startday.to_date..end_day.to_date,status: "r",user_id: entry.user_id)
    #   if status_l1.present? && work_days.present? && status_l1.length >= work_days.count
    if status_l1.present? && work_days.present? && status_l1.length >= 4
      final_status_l1 = status_l1.map(&:status).uniq
    end
    if status_l2.present? && work_days.present? && status_l2.length >= 4
      final_status_l2= status_l2.map(&:status).uniq
    end
    if status_l3.present? && work_days.present? && status_l3.length >= 4
      final_status_l3= status_l3.map(&:status).uniq
    end
    if final_status_l3.present? && final_status_l3.length==1
      status = "l3"
    elsif final_status_l2.present? && final_status_l2.length==1
      status = "l2"
    elsif final_status_l1.present? && final_status_l1.length==1
      status = "l1"
    elsif status_r.present? && status_r.length > 4
      status = "r"
    end


    statusStr = l(:wk_status_new)
    case status
      when 'l1'
        statusStr = l(:wk_status_l1_approved)
      when 'l2'
        statusStr = l(:wk_status_l2_approved)
      when 'l3'
        statusStr = l(:wk_status_l3_approved)
      when 'r'
        statusStr = l(:wk_status_rejected)
      when 's'
        statusStr = l(:wk_status_submitted)
      else
        statusStr = l(:wk_status_new)
    end
    return statusStr
  end

  # Indentation of Subprojects based on levels
  def options_for_wktime_project(projects, needBlankRow=false)
    projArr = Array.new
    if needBlankRow
      projArr << [ "", ""]
    end

    #Project.project_tree(projects) do |proj_name, level|
    project_tree(projects) do |proj, level|
      indent_level = (level > 0 ? ('&nbsp;' * 2 * level + '&#187; ').html_safe : '')
      sel_project = projects.select{ |p| p.id == proj.id }
      projArr << [ (indent_level + sel_project[0].name), sel_project[0].id ]
    end
    projArr
  end

  # Returns a CSV string of a weekly timesheet
  def wktime_to_csv(entries, user, startday, unitLabel)
    decimal_separator = l(:general_csv_decimal_separator)
    custom_fields = WktimeCustomField.find(:all)
    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # csv header fields
      headers = [l(:field_user),
                 l(:field_project),
                 l(:field_issue),
                 l(:field_activity)
      ]
      if !unitLabel.blank?
        headers << l(:label_wk_currency)
      end
      unit=nil

      set_cf_header(headers, nil, 'wktime_enter_cf_in_row1')
      set_cf_header(headers, nil, 'wktime_enter_cf_in_row2')

      hoursIndex = headers.size
      startOfWeek = getStartOfWeek
      for i in 0..6
        #Use "\n" instead of '\n'
        #Martin Dube contribution: 'start of the week' configuration
        headers << (l('date.abbr_day_names')[(i+startOfWeek)%7] + "\n" + I18n.localize(@startday+i, :format=>:short)) unless @startday.nil?
      end
      csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(
          c.to_s, l(:general_csv_encoding) )  }
      weeklyHash = getWeeklyView(entries, unitLabel, true) #should send false and form unique rows
      col_values = []
      matrix_values = nil
      totals = [0.0,0.0,0.0,0.0,0.0,0.0,0.0]
      weeklyHash.each do |key, matrix|
        matrix_values, j = getColumnValues(matrix, totals, unitLabel,false,0)
        col_values = matrix_values[0]
        #add the user name to the values
        col_values.unshift(user.name)
        csv << col_values.collect {|c| Redmine::CodesetUtil.from_utf8(
            c.to_s, l(:general_csv_encoding) )  }
        if !unitLabel.blank?
          unit=matrix_values[0][4]
        end
      end
      total_values = getTotalValues(totals, hoursIndex,unit)
      #add an empty cell to cover for the user column
      #total_values.unshift("")
      csv << total_values.collect {|t| Redmine::CodesetUtil.from_utf8(
          t.to_s, l(:general_csv_encoding) )  }
    end
    export
  end


  # Returns a PDF string of a weekly timesheet
  def wktime_to_pdf(entries, user, startday, unitLabel)

    # Landscape A4 = 210 x 297 mm
    page_height   = Setting.plugin_redmine_wktime['wktime_page_height'].to_i
    page_width    = Setting.plugin_redmine_wktime['wktime_page_width'].to_i
    right_margin  = Setting.plugin_redmine_wktime['wktime_margin_right'].to_i
    left_margin  = Setting.plugin_redmine_wktime['wktime_margin_left'].to_i
    bottom_margin = Setting.plugin_redmine_wktime['wktime_margin_bottom'].to_i
    top_margin = Setting.plugin_redmine_wktime['wktime_margin_top'].to_i
    col_id_width  = 10
    row_height    = Setting.plugin_redmine_wktime['wktime_line_space'].to_i
    logo    = Setting.plugin_redmine_wktime['wktime_header_logo']

    if page_height == 0
      page_height = 297
    end
    if page_width == 0
      page_width  = 210
    end
    if right_margin == 0
      right_margin = 10
    end
    if left_margin == 0
      left_margin = 10
    end
    if bottom_margin == 0
      bottom_margin = 20
    end
    if top_margin == 0
      top_margin = 20
    end
    if row_height == 0
      row_height = 4
    end

    # column widths
    table_width = page_width - right_margin - left_margin

    columns = ["#",l(:field_project), l(:field_issue), l(:field_activity)]


    col_width = []
    orientation = "P"
    unit=nil
    # 20% for project, 60% for issue, 20% for activity
    col_width[0]=col_id_width
    col_width[1] = (table_width - (8*10))*0.2
    col_width[2] = (table_width - (8*10))*0.6
    col_width[3] = (table_width - (8*10))*0.2
    title=l(:label_wktime)
    if !unitLabel.blank?
      columns << l(:label_wk_currency)
      col_id_width  = 14
      col_width[0]=col_id_width
      col_width[1] = (table_width - (8*14))*0.20
      col_width[2] = (table_width - (8*14))*0.45
      col_width[3] = (table_width - (8*14))*0.15
      col_width[4] = (table_width - (8*14))*0.20
      title= l(:label_wkexpense)
    end

    set_cf_header(columns, col_width, 'wktime_enter_cf_in_row1')
    set_cf_header(columns, col_width, 'wktime_enter_cf_in_row2')

    hoursIndex = columns.size
    startOfWeek = getStartOfWeek
    for i in 0..6
      #Martin Dube contribution: 'start of the week' configuration
      columns << l('date.abbr_day_names')[(i+startOfWeek)%7] + "\n" + (startday+i).mon().to_s() + "/" + (startday+i).day().to_s()
      col_width << col_id_width
    end

    #Landscape / Potrait
    if(table_width > 220)
      orientation = "L"
    else
      orientation = "P"
    end

    pdf = ITCPDF.new(current_language)

    pdf.SetTitle(title)
    pdf.alias_nb_pages
    pdf.footer_date = format_date(Date.today)
    pdf.SetAutoPageBreak(false)
    pdf.AddPage(orientation)

    if !logo.blank? && (File.exist? (Redmine::Plugin.public_directory + "/redmine_wktime/images/" + logo))
      pdf.Image(Redmine::Plugin.public_directory + "/redmine_wktime/images/" + logo, page_width-10-20, 10)
    end

    render_header(pdf, entries, user, startday, row_height,title)

    pdf.Ln
    render_table_header(pdf, columns, col_width, row_height, table_width)

    weeklyHash = getWeeklyView(entries, unitLabel, true)
    col_values = []
    matrix_values = []
    totals = [0.0,0.0,0.0,0.0,0.0,0.0,0.0]
    grand_total = 0.0
    j = 0
    base_x = pdf.GetX
    base_y = pdf.GetY
    max_height = row_height

    weeklyHash.each do |key, matrix|
      matrix_values, j = getColumnValues(matrix, totals, unitLabel,true, j)
      col_values = matrix_values[0]
      base_x = pdf.GetX
      base_y = pdf.GetY
      pdf.SetY(2 * page_height)

      #write once to get the height
      max_height = wktime_to_pdf_write_cells(pdf, col_values, col_width, row_height)
      #reset the x and y
      pdf.SetXY(base_x, base_y)

      # make new page if it doesn't fit on the current one
      space_left = page_height - base_y - bottom_margin
      if max_height > space_left
        render_newpage(pdf,orientation,logo,page_width)
        render_table_header(pdf, columns, col_width, row_height,  table_width)
        base_x = pdf.GetX
        base_y = pdf.GetY
      end

      # write the cells on page
      wktime_to_pdf_write_cells(pdf, col_values, col_width, row_height)
      issues_to_pdf_draw_borders(pdf, base_x, base_y, base_y + max_height, 0, col_width)
      pdf.SetY(base_y + max_height);
      if !unitLabel.blank?
        unit=matrix_values[0][4]
      end
    end

    total_values = getTotalValues(totals,hoursIndex,unit)

    #write total
    #write an empty id

    max_height = wktime_to_pdf_write_cells(pdf, total_values, col_width, row_height)

    pdf.SetY(pdf.GetY + max_height);
    pdf.SetXY(pdf.GetX, pdf.GetY)

    render_signature(pdf, page_width, table_width, row_height,bottom_margin,page_height,orientation,logo)
    pdf.Output
  end

  # Renders MultiCells and returns the maximum height used
  def wktime_to_pdf_write_cells(pdf, col_values, col_widths,
                                row_height)
    base_y = pdf.GetY
    max_height = row_height
    col_values.each_with_index do |val, i|
      col_x = pdf.GetX
      pdf.RDMMultiCell(col_widths[i], row_height, val, "T", 'L', 1)
      max_height = (pdf.GetY - base_y) if (pdf.GetY - base_y) > max_height
      pdf.SetXY(col_x + col_widths[i], base_y);
    end
    return max_height
  end
  #new page logo
  def render_newpage(pdf,orientation,logo,page_width)
    pdf.AddPage(orientation)
    if !logo.blank? && (File.exist? (Redmine::Plugin.public_directory + "/redmine_wktime/images/" + logo))
      pdf.Image(Redmine::Plugin.public_directory + "/redmine_wktime/images/" + logo, page_width-10-20, 10)
      pdf.Ln
      pdf.SetY(pdf.GetY+10)
    end
  end

  def getKey(entry,unitLabel)
    cf_in_row1_value = nil
    cf_in_row2_value = nil
    key = entry.project.id.to_s + (entry.issue.blank? ? '' : entry.issue.id.to_s) + entry.activity.id.to_s + (unitLabel.blank? ? '' : entry.currency)
    entry.custom_field_values.each do |custom_value|
      custom_field = custom_value.custom_field
      if (!Setting.plugin_redmine_wktime['wktime_enter_cf_in_row1'].blank? &&	Setting.plugin_redmine_wktime['wktime_enter_cf_in_row1'].to_i == custom_field.id)
        cf_in_row1_value = custom_value.to_s
      end
      if (!Setting.plugin_redmine_wktime['wktime_enter_cf_in_row2'].blank? && Setting.plugin_redmine_wktime['wktime_enter_cf_in_row2'].to_i == custom_field.id)
        cf_in_row2_value = custom_value.to_s
      end
    end
    if (!cf_in_row1_value.blank?)
      key = key + cf_in_row1_value
    end
    if (!cf_in_row2_value.blank?)
      key = key + cf_in_row2_value
    end
    if (!Setting.plugin_redmine_wktime['wktime_enter_comment_in_row'].blank? && Setting.plugin_redmine_wktime['wktime_enter_comment_in_row'].to_i == 1)
      if(!entry.comments.blank?)
        key = key + entry.comments
      end
    end
    key
  end

  def getWeeklyView(entries, unitLabel, sumHours = false)
    weeklyHash = Hash.new
    prev_entry = nil
    entries.each do |entry|
      # If a project is deleted all its associated child table entries will get deleted except wk_expense_entries
      # So added !entry.project.blank? check to remove deleted projects
      if !entry.project.blank?
        key = getKey(entry,unitLabel)
        hourMatrix = weeklyHash[key]
        if hourMatrix.blank?
          #create a new matrix if not found
          hourMatrix =  []
          rows = []
          hourMatrix[0] = rows
          weeklyHash[key] = hourMatrix
        end

        #Martin Dube contribution: 'start of the week' configuration
        #wday returns 0 - 6, 0 is sunday
        startOfWeek = getStartOfWeek
        index = (entry.spent_on.wday+7-(startOfWeek))%7
        updated = false
        hourMatrix.each do |rows|
          if rows[index].blank?
            rows[index] = entry
            updated = true
            break
          else
            if sumHours
              tempEntry = rows[index]
              tempEntry.hours += entry.hours
              updated = true
              break
            end
          end
        end
        if !updated
          rows = []
          hourMatrix[hourMatrix.size] = rows
          rows[index] = entry
        end
      end
    end
    return weeklyHash
  end

  def getColumnValues(matrix, totals, unitLabel,rowNumberRequired, j=0)
    col_values = []
    matrix_values = []
    k=0
    unless matrix.blank?
      matrix.each do |rows|
        issueWritten = false
        col_values = []
        matrix_values << col_values
        hoursIndex = 3
        if rowNumberRequired
          col_values[0] = (j+1).to_s
          k=1
        end

        rows.each.with_index do |entry, i|
          unless entry.blank?
            if !issueWritten
              col_values[k] = entry.project.name
              col_values[k+1] = entry.issue.blank? ? "" : entry.issue.subject
              col_values[k+2] = entry.activity.name
              if !unitLabel.blank?
                col_values[k+3]= entry.currency
              end
              custom_field_values = entry.custom_field_values
              set_cf_value(col_values, custom_field_values, 'wktime_enter_cf_in_row1')
              set_cf_value(col_values, custom_field_values, 'wktime_enter_cf_in_row2')
              hoursIndex = col_values.size
              issueWritten = true
              j += 1
            end
            col_values[hoursIndex+i] =  (entry.hours.blank? ? "" : ("%.2f" % entry.hours.to_s))
            totals[i] += entry.hours unless entry.hours.blank?
          end
        end
      end
    end
    return matrix_values, j
  end

  def getTotalValues(totals, hoursIndex,unit)
    grand_total = 0.0
    totals.each { |t| grand_total += t }
    #project, issue, is blank, and then total
    total_values = []
    for i in 0..hoursIndex-2
      total_values << ""
    end
    total_values << "#{l(:label_total)} = #{unit} #{("%.2f" % grand_total)}"
    #concatenate two arrays
    total_values += totals.collect{ |t| "#{unit} #{("%.2f" % t.to_s)}"}
    return total_values
  end


  def render_table_header(pdf, columns, col_width, row_height, table_width)
    # headers
    pdf.SetFontStyle('B',8)
    pdf.SetFillColor(230, 230, 230)

    # render it background to find the max height used
    base_x = pdf.GetX
    base_y = pdf.GetY
    max_height = wktime_to_pdf_write_cells(pdf, columns, col_width, row_height)
    #pdf.Rect(base_x, base_y, table_width + col_id_width, max_height, 'FD');
    pdf.Rect(base_x, base_y, table_width, max_height, 'FD');
    pdf.SetXY(base_x, base_y);

    # write the cells on page
    wktime_to_pdf_write_cells(pdf, columns, col_width, row_height)
    issues_to_pdf_draw_borders(pdf, base_x, base_y, base_y + max_height,0, col_width)
    pdf.SetY(base_y + max_height);

    # rows
    pdf.SetFontStyle('',8)
    pdf.SetFillColor(255, 255, 255)
  end

  def render_header(pdf, entries, user, startday, row_height,title)
    base_x = pdf.GetX
    base_y = pdf.GetY

    # title
    pdf.SetFontStyle('B',11)
    pdf.RDMCell(100,10, title)
    pdf.SetXY(base_x, pdf.GetY+row_height)

    render_header_elements(pdf, base_x, pdf.GetY+row_height, l(:field_name), user.name)
    #render_header_elements(pdf, base_x, pdf.GetY+row_height, l(:field_project), entries.blank? ? "" : entries[0].project.name)
    render_header_elements(pdf, base_x, pdf.GetY+row_height, l(:label_week), startday.to_s + " - " + (startday+6).to_s)
    render_customFields(pdf, base_x, user, startday, row_height)
    pdf.SetXY(base_x, pdf.GetY+row_height)
  end

  def render_customFields(pdf, base_x, user, startday, row_height)
    if !@wktime.blank? && !@wktime.custom_field_values.blank?
      @wktime.custom_field_values.each do |custom_value|
        render_header_elements(pdf, base_x, pdf.GetY+row_height,
                               custom_value.custom_field.name, custom_value.value)
      end
    end
  end

  def render_header_elements(pdf, x, y, element, value="")

    pdf.SetXY(x, y)
    unless element.blank?
      pdf.SetFontStyle('B',8)
      pdf.RDMCell(50,10, element)
      pdf.SetXY(x+40, y)
      pdf.RDMCell(10,10, ":")
      pdf.SetFontStyle('',8)
      pdf.SetXY(x+40+2, y)
    end
    pdf.RDMCell(50,10, value)

  end

  def render_signature(pdf, page_width, table_width, row_height,bottom_margin,page_height,orientation,logo)
    base_x = pdf.GetX
    base_y = pdf.GetY

    submissionAck   = Setting.plugin_redmine_wktime['wktime_submission_ack']

    unless submissionAck.blank?
      check_render_newpage(pdf,page_height,row_height,bottom_margin,submissionAck,orientation,logo,page_width)
      #pdf.SetY(base_y + row_height)
      #pdf.SetXY(base_x, pdf.GetY+row_height)
      #to wrap text and to put it in multi line use MultiCell
      pdf.RDMMultiCell(table_width,5, submissionAck)
      submissionAck= nil
    end
    check_render_newpage(pdf,page_height,row_height,bottom_margin,submissionAck,orientation,logo,page_width)

    pdf.SetFontStyle('B',8)
    pdf.SetXY(page_width-90, pdf.GetY+row_height)
    pdf.RDMCell(50,10, l(:label_wk_signature) + " :")
    pdf.SetXY(page_width-90, pdf.GetY+(2*row_height))
    pdf.RDMCell(100,10, l(:label_wk_submitted_by) + " ________________________________")
    pdf.SetXY(page_width-90, pdf.GetY+ (2*row_height))
    pdf.RDMCell(100,10, l(:label_wk_approved_by) + " ________________________________")
  end
  #check_render_newpage
  def check_render_newpage(pdf,page_height,row_height,bottom_margin,submissionAck,orientation,logo,page_width)
    base_y = pdf.GetY
    if(!submissionAck.blank?)
      space_left = page_height - (base_y+(7*row_height)) - bottom_margin
    else
      space_left = page_height - (base_y+(5*row_height)) - bottom_margin
    end
    if(space_left<0)
      render_newpage(pdf,orientation,logo,page_width)
    end
  end
  def set_cf_header(columns, col_width, setting_name)
    cf_value = nil
    if !Setting.plugin_redmine_wktime[setting_name].blank? && !@new_custom_field_values.blank? &&
        (cf_value = @new_custom_field_values.detect { |cfv|
          cfv.custom_field.id == Setting.plugin_redmine_wktime[setting_name].to_i }) != nil

      columns << cf_value.custom_field.name
      unless col_width.blank?
        old_total = 0
        new_total = 0
        for i in 0..col_width.size-1
          old_total += col_width[i]
          if i == 1
            col_width[i] -= col_width[i]*10/100
          else
            col_width[i] -= col_width[i]*20/100
          end
          new_total += col_width[i]
        end
        # reset width 15% for project, 55% for issue, 15% for activity
        #col_width[0] *= 0.75
        #col_width[1] *= 0.9
        #col_width[2] *= 0.75

        col_width << old_total - new_total
      end
    end
  end

  def set_cf_value(col_values, custom_field_values, setting_name)
    cf_value = nil
    if !Setting.plugin_redmine_wktime[setting_name].blank? &&
        (cf_value = custom_field_values.detect { |cfv|
          cfv.custom_field.id == Setting.plugin_redmine_wktime[setting_name].to_i }) != nil
      col_values << cf_value.value
    end
  end

  def getTimeEntryStatus(spent_on,user_id)
    result = Wktime.find(:all, :conditions => [ 'begin_date = ? AND user_id = ?', getStartDay(spent_on), user_id])
    return result[0].blank? ? 'n' : result[0].status
  end

  def time_expense_tabs
    tabs = [
        {:name => 'wktime', :partial => 'wktime/tab_content', :label => :label_wktime},
        {:name => 'wkexpense', :partial => 'wktime/tab_content', :label => :label_wkexpense}
    ]
  end

  #change the date to first day of week
  def getStartDay(date)
    startOfWeek = getStartOfWeek
    #Martin Dube contribution: 'start of the week' configuration
    unless date.nil?
      #the day of calendar week (0-6, Sunday is 0)
      dayfirst_diff = (date.wday+7) - (startOfWeek)
      date -= (dayfirst_diff%7)
    end
    date
  end

  #Code snippet taken from application_helper.rb  - include_calendar_headers_tags method
  def getStartOfWeek
    start_of_week = Setting.start_of_week
    start_of_week = l(:general_first_day_of_week, :default => '1') if start_of_week.blank?
    start_of_week = start_of_week.to_i % 7
  end

  def sendNonSubmissionMail
    startDate = getStartDay(Date.today)
    deadline = Date.today
    #No. of working days between startOfWeek and submissionDeadline
    diff = working_days(startDate,deadline + 1)
    countOfWorkingDays = 7 - (Setting.non_working_week_days).size
    if diff != countOfWorkingDays
      startDate = startDate-7
    end

    queryStr =  "select distinct u.* from projects p" +
        " inner join members m on p.id = m.project_id and p.status not in (#{Project::STATUS_CLOSED},#{Project::STATUS_ARCHIVED})"  +
        " inner join member_roles mr on m.id = mr.member_id" +
        " inner join roles r on mr.role_id = r.id and r.permissions like '%:log_time%'" +
        " inner join users u on m.user_id = u.id" +
        " left outer join wktimes w on u.id = w.user_id and w.begin_date = '" + startDate.to_s + "'" +
        " where (w.status is null or w.status = 'n')"

    users = User.find_by_sql(queryStr)
    users.each do |user|
      WkMailer.nonSubmissionNotification(user,startDate).deliver
    end
  end


  def send_l1_non_approve_notification(user_id)
    user = User.where(:user_id=> user_id).last
    body +="\n #{l(:field_name)} : #{user.firstname} #{user.lastname} \n #{total}"
    body +="\n #{l(:label_wk_rejected_days)} : #{dates}"
    body +="\n #{l(:label_wk_rejectedby)} : #{current_user.firstname} #{current_user.lastname}"
    body +="\n #{l(:label_wk_rejectedon)} : #{set_time_zone(Time.now)}"
    body +="\n"
    mail :from => current_user.mail,:to => user.mail, :subject => subject,:body => body
    mail :from => Setting.mail_from ,:to => user.mail, :subject => subject,:body => body
  end

  # check the log duration days includes any weekends if exists than we go for a previous day
  def confirm_with_weekends(dead_line, log_duration, today)
    range = dead_line...today
    range.collect do |day|
      if day.wday == 6 || day.wday == 0
        log_duration = log_duration.to_i + 1
      end
    end
    day = (today - 1 - log_duration.to_i).wday
    if day == 0 || day == 6
      log_duration = log_duration.to_i + 1
    end
    return log_duration, day
  end

  # check the log duration days includes any holidays if exists than we go for a previous day
  def confirm_with_holidays(log_duration, dead_line, today, holidays)
    weekend = []
    new_range = ((today - 1 - log_duration.to_i)...today)
    new_range.each {|d| weekend << d if d.wday == 6 || d.wday==0}
    week_holidays = []
    new_range.each do|weekday|
      holidays.each { |day| week_holidays << day if day.to_date ==weekday.to_date }
    end
    final_dead_line =  dead_line - weekend.size - week_holidays.size
    holidays_list = holidays.include? (Date.today).strftime '%Y-%m-%d'
    return final_dead_line, holidays_list
  end


  #Update the record if user TimeEntry is not exist in the day.
  def lock_user_timesheet(today, final_dead_line, holidays_list, day)
    nonloged_users = []
    if today.wday != 6 || today.wday != 0 || holidays_list
      if !day === today.strftime('%Y-%m-%d') || today.wday != 6 || today.wday != 0
        User.active.all.collect do |user|
          # other_entries = TimeEntry.where(:user_id=> user.id).where("spent_on > ? ", (final_dead_line-30).strftime('%Y-%m-%d'))
          rec = TimeEntry.where(:user_id=> user.id, :spent_on => final_dead_line)
          if rec == []
            nonloged_users << user
          end
        end
        nonloged_users.collect do |user|
          #LockUserEntry.create(:user_id => user.id, :due_date => final_dead_line.to_datetime, :lock => true)
          log_rec = LockUserEntry.find_or_create_by_user_id_and_due_date(:user_id=> user.id,:due_date=>final_dead_line)
          log_rec.update_attributes(:lock=>true)
          WkMailer.missingLogNotification(user,final_dead_line).deliver
        end
      end
    end
  end


  def getDateSqlString(dtfield)
    startOfWeek = getStartOfWeek
    # postgre doesn't have the weekday function
    # The day of the week (0 - 6; Sunday is 0)
    if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
      sqlStr = dtfield + " - ((cast(extract(dow from " + dtfield + ") as integer)+7-" + startOfWeek.to_s + ")%7)"
    elsif ActiveRecord::Base.connection.adapter_name == 'SQLite'
      sqlStr = "date(" + dtfield  + " , '-' || ((strftime('%w', " + dtfield + ")+7-" + startOfWeek.to_s + ")%7) || ' days')"
    elsif ActiveRecord::Base.connection.adapter_name == 'SQLServer'
      sqlStr = "DateAdd(d, (((((DATEPART(dw," + dtfield + ")-1)%7)-1)+(8-" + startOfWeek.to_s + ")) % 7)*-1," + dtfield + ")"
    else
      # mysql - the weekday index for date (0 = Monday, 1 = Tuesday, � 6 = Sunday)
      sqlStr = "adddate(" + dtfield + ",mod(weekday(" + dtfield + ")+(8-" + startOfWeek.to_s + "),7)*-1)"
    end
    sqlStr
  end

  def getHostAndDir(req)
    "#{req.url}".gsub("#{req.path_info}","").gsub("#{req.protocol}","")
  end

  def getNonWorkingDayColumn(startDate)
    startOfWeek = getStartOfWeek
    ndays = Setting.non_working_week_days
    columns =''
    ndays.each do |day|
      columns << ',' if !columns.blank?
      columns << ((((day.to_i +7) - startOfWeek ) % 7) + 1).to_s
    end
    publicHolidayColumn = getPublicHolidayColumn(startDate)
    publicHolidayColumn = publicHolidayColumn.join(',') if !publicHolidayColumn.nil?
    columns << ","  if !publicHolidayColumn.blank? && !columns.blank?
    columns << publicHolidayColumn if !publicHolidayColumn.blank?
    columns
  end

  def settings_tabs
    tabs = [
        {:name => 'general', :partial => 'settings/tab_general', :label => :label_general},
        {:name => 'display', :partial => 'settings/tab_display', :label => :label_display},
        {:name => 'wktime', :partial => 'settings/tab_time', :label => :label_wktime},
        {:name => 'wkexpense', :partial => 'settings/tab_expense', :label => :label_wkexpense},
        {:name => 'approval', :partial => 'settings/tab_approval', :label => :label_wk_approval_system},
        {:name => 'publicHoliday', :partial => 'settings/tab_holidays', :label => :label_wk_public_holiday}
    ]
  end

  def getPublicHolidays()
    holidays = nil
    publicHolidayList = Setting.plugin_redmine_wktime['wktime_public_holiday']
    if !publicHolidayList.blank?
      holidays = Array.new
      publicHolidayList.each do |holiday|
        holidays << holiday.split('|')[0].strip rescue nil
      end
    end
    holidays
  end

  def checkHoliday(timeEntryDate,publicHolidays)
    isHoliday = false
    if !publicHolidays.nil?
      isHoliday = true if publicHolidays.include? timeEntryDate
    end
    isHoliday
  end

  def getPublicHolidayColumn(date)
    columns =nil
    startDate = getStartDay(date.to_date)
    publicHolidays = getPublicHolidays()
    if !publicHolidays.nil?
      columns = Array.new
      for i in 0..6
        columns << (i+1).to_s if checkHoliday((startDate.to_date + i).to_s,publicHolidays)
      end
    end
    columns
  end

  # Returns week day of public holiday
  # mon - sun --> 1 - 7
  def getWdayForPublicHday(startDate)
    pHdays = getPublicHolidays()
    wDayOfPublicHoliday = Array.new
    if !pHdays.blank?
      for i in 0..6
        wDayOfPublicHoliday << ((startDate+i).cwday).to_s if checkHoliday((startDate + i).to_s,pHdays)
      end
    end
    wDayOfPublicHoliday
  end

  def checkViewPermission
    ret =  false
    if User.current.logged?
      viewProjects = Project.find(:all, :conditions => Project.allowed_to_condition(User.current, :view_time_entries ))
      loggableProjects ||= Project.find(:all, :conditions => Project.allowed_to_condition(User.current, :log_time))
      ret = (!viewProjects.blank? && viewProjects.size > 0) || (!loggableProjects.blank? && loggableProjects.size > 0)
    end
    ret
  end

  def is_number(val)
    true if Float(val) rescue false
  end


  # Lock Unlocking Methods And L1 L2 approval

  def lock_unlock_users
    @unlocks = LockUserEntry.where(:lock=>false)
    if @unlocks.present?
      @unlocks.each do |unlock_rec|
        find_rec = TimeEntry.where(:user_id=> unlock_rec.user_id, :spent_on => unlock_rec.due_date)
        if !find_rec.present?
          unlock_rec.update_attributes(:lock=> true)
        else
          unlock_rec.delete
        end
      end
    end
  end
  def user_permission_list(projects)
    if projects.present?
      project = projects.last.member_principals.find_by_user_id(User.current.id)
      if project.present?
        project.member_roles.last.role.permissions
      else
        []
      end
    else
      []
    end
  end


# check permissions for L1 and L1 Approval
  def check_permission_list(l,first_entry)
    @user = User.current
    log_projects = Project.find(:all, :order => 'name',:conditions => Project.allowed_to_condition(@user, :log_time))

    members = []
    permissions = []
    log_projects.each { |rec| members << rec.member_principals.find_by_user_id(User.current.id)  }
    members.flatten.each do |rec|
      rec.member_roles.each { |rec| permissions << rec.role.permissions } if rec.present?
    end

    if permissions.flatten.present? && (permissions.flatten.include?(l.to_sym) || permissions.flatten.include?(l.to_sym))
      return true
    else
      return false
    end
  end

  # check other manager accpet the log hours
  def check_other_projects(rec, role)
    members = []
    permissions = []

    project = Project.find(rec.project_id)
    members << project.member_principals.find_by_user_id(User.current.id)
    members.flatten.each do |rec|
      rec.member_roles.each { |rec| permissions << rec.role.permissions } if rec.present?
    end
    wk = Wktime.where(:project_id => project.id, :statusupdater_id => User.current.id)
    if permissions.flatten.present? && permissions.flatten.include?(role)
      return true
    else
      return false
    end
  end

# check L2 status for the day
  def check_l2_status(user_id,date)
    status_l2 =Wktime.where(:user_id=>user_id,:begin_date=>date,:status=>'l2')
    l2_entry = TimeEntry.where(:spent_on=> date,:user_id=>user_id)
    if  status_l2.present?
      true
    end
  end

# check time log entry for the day
#   def check_time_log_entry(select_time,current_user)
#     days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
#     setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
#     setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
#     current_time = set_time_zone(Time.now)
#     expire_time = return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")
#     #deadline_date = (Date.today-days.to_i).strftime('%Y-%m-%d').to_date
#     date = UserUnlockEntry.dead_line
#
#    # p "+++++++++dead date +++++"
#    #  p date
#    #  p "+++++++++++"
#     if date.present?
#       deadline_date = date.to_date.strftime('%Y-%m-%d').to_date
#     end
#     lock_status = UserUnlockEntry.where(:user_id=>current_user.id)
#     if lock_status.present?
#       lock_status_expire_time = lock_status.last.expire_time
#       if lock_status_expire_time.to_date <= expire_time.to_date
#         lock_status.delete_all
#       end
#     end
#     entry_status =  TimeEntry.where(:user_id=>current_user.id,:spent_on=>select_time.to_date.strftime('%Y-%m-%d').to_date)
#     #lock_status = UserUnlockEntry.where(:user_id=>current_user.id)
#     permanent_unlock = PermanentUnlock.where(:user_id=>current_user.id)
#     p "++++++++deadline_date++++++"
#     p deadline_date
#     p "+++++++++++++selec"
#     p select_time.to_date
#     p "++++++++expire+++++++"
#     p expire_time
#     p "++++++current++"
#     p current_time
#     p "+++++++++++end ++++++++++++"
#     if (select_time.to_date > deadline_date.to_date || lock_status.present?) || ( permanent_unlock.present? && permanent_unlock.last.status == true)
#       return true
#     elsif (select_time.to_date == deadline_date.to_date && expire_time > current_time) || lock_status.present? || (permanent_unlock.present? && permanent_unlock.last.status == true)
#       return true
#     else
#       return false
#     end
#   end

  def check_time_log_entry(select_time,current_user)
    days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")
    deadline_date = UserUnlockEntry.dead_line_final_method
    if deadline_date.present?
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
    permanent_unlock = PermanentUnlock.where(:user_id=>current_user.id)

    if ((select_time.to_date > deadline_date.to_date || lock_status.present?) || ( permanent_unlock.present? && permanent_unlock.last.status == true)) && (!wiki_status_l1.present? && !wiki_status_l2.present? && !wiki_status_l3.present?)

      return true

    elsif ((select_time.to_date == deadline_date.to_date && expire_time > current_time) || lock_status.present? || (permanent_unlock.present? && permanent_unlock.last.status == true)) && ((!wiki_status_l1.present? && !wiki_status_l2.present? && !wiki_status_l3.present?))

      return true
    else

      return false
    end

  end

  def check_time_log_entry_for_approve(select_time,current_user)
    days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
    #current_time = Time.now
    #expire_time = Time.new(current_time.year, current_time.month, current_time.day,setting_hr,setting_min,1, "+05:30")
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")
    # deadline_date = (current_time.to_date-days.to_i).strftime('%Y-%m-%d').to_date
    deadline_date = UserUnlockEntry.dead_line_final_method
    if deadline_date.present?
      #date = date - days.to_i
      deadline_date = deadline_date.to_date.strftime('%Y-%m-%d').to_date
    end
    # lock_status = UserUnlockEntry.where(:user_id=>current_user.id)
    # if lock_status.present?
    #   lock_status_expire_time = lock_status.last.expire_time
    #   if lock_status_expire_time.to_date <= expire_time.to_date
    #     lock_status.delete_all
    #   end
    # end
    entry_status =  TimeEntry.where(:user_id=>current_user.id,:spent_on=>select_time.to_date.strftime('%Y-%m-%d').to_date)
    wiki_status_l1=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l1")
    wiki_status_l2=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l2")
    wiki_status_l3=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l3")
    #lock_status = UserUnlockEntry.where(:user_id=>current_user.id)
    # permanent_unlock = PermanentUnlock.where(:user_id=>current_user.id)
    if ((select_time.to_date > deadline_date.to_date )) && (!wiki_status_l1.present? && !wiki_status_l2.present? && !wiki_status_l3.present?)

      return true

    elsif ((select_time.to_date == deadline_date.to_date && expire_time > current_time) ) && ((!wiki_status_l1.present? && !wiki_status_l2.present? && !wiki_status_l3.present?))

      return true
    else

      return false
    end

  end



# check l1 status for the week
  def check_l1_status_for_week(select_time,user)
    startday = select_time.to_date
    end_day = (select_time.to_date + 6)
    work_days = []
    l1_dates = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      else
        work_days << day
        l1_date  = Wktime.where(begin_date: day,status: "l1",:user_id=>user)
        if l1_date.present?
          l1_dates << day
        end
      end
    end
    if l1_dates.present?
      return true
    else
      return  false
    end
  end
# check working days for the week

  def check_work_days_for_week(select_time,user)
    startday = select_time.to_date
    end_day = (select_time.to_date + 6)
    work_days = []
    l1_dates = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      else
        work_days << day
        l1_date  = TimeEntry.where(spent_on: day,:user_id=>user)
        if l1_date.present?
          l1_dates << day
        end
      end
    end
    if l1_dates.present?
      return true
    else
      return  false
    end
  end
# check l2 status for week
  def check_l2_status_for_week(select_time,user, role)
    startday = select_time.to_date
    end_day = (select_time.to_date + 6)
    work_days = []
    l2_dates = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      else
        work_days << day
        l2_date  = Wktime.where(begin_date: day,status: role,:user_id=>user)
        if l2_date.present?
          l2_dates << day
        end
      end
    end
    #status = Wktime.where(begin_date: startday..end_day,status: "l1",:user_id=>user)
    if l2_dates.present? && work_days.present? && l2_dates.count >=work_days.count
      return true
    else
      return  false
    end
  end

  def check_time_entry_for_week(select_time,user)
    startday = select_time.to_date
    check_status=[]
    end_day = (startday+6)
    (startday..end_day).each do |day|
      #status = check_time_log_entry(day,user)
      date1_time_entry = TimeEntry.where(:spent_on=> day.to_date,:user_id=>user)
      if date1_time_entry.present?
        check_status << true
      else
        check_status << false
      end
    end
    if check_status.present? &&  !check_status.include?(false)
      return true
    end

  end


  def check_lock_status_for_week(startday,id)
    user = User.where(:id=>id).last
    check_status=[]
    end_day = (startday+6)
    (startday..end_day).each do |day|
      status = check_time_log_entry(day,user)
      check_status << status
    end
    if check_status.present? && !check_status.include?(false)
      return true
    end
  end
  def set_time_zone(time)
    return_time_zone
    Time.zone.at(time)
  end
  def return_time_zone
    current_zone = User.current.pref.time_zone.present? ? User.current.pref.time_zone :  "Chennai"
    Time.zone = current_zone
    Time.zone
  end

# L3 approval

  def check_permission_list_project_id(l,project_2)

    project = Project.where(id:project_2).last if project_2.present?
    logtime_projects = User.current.roles_for_project(project)
    if project.present? && logtime_projects.present?
      if (l == "l1")
        check_l1 = logtime_projects.last.permissions.include? l.to_sym
        check_l2 = logtime_projects.last.permissions.include? "l2".to_sym
        if check_l1.present? && !check_l2.present?
          return true
        end
      elsif(l == "l2")
        if logtime_projects.last.permissions.include? l.to_sym
          return true
        end
      elsif(l == "l3")
        if logtime_projects.last.permissions.include? l.to_sym
          return true
        end
      end
    else
    end
  end

  def getStartOfMonth(date)
    week_day = date.strftime("%w").to_i

    # start_of_week = Setting.start_of_week
    # start_of_week = l(:general_first_day_of_week, :default => '1') if start_of_week.blank?
    # start_of_week = start_of_week.to_i % 30
    return week_day
  end

  def getMonthlyView(entries, unitLabel, sumHours = false,end_date)
    weeklyHash = Hash.new
    prev_entry = nil
    entries.each do |entry|

      # If a project is deleted all its associated child table entries will get deleted except wk_expense_entries
      # So added !entry.project.blank? check to remove deleted projects
      if !entry.project.blank?

        key = getKey(entry,unitLabel) rescue nil

        hourMatrix = weeklyHash[key]

        if hourMatrix.blank?
          #create a new matrix if not found
          hourMatrix =  []
          rows = []
          hourMatrix[0] = rows
          weeklyHash[key] = hourMatrix
        end

        #Martin Dube contribution: 'start of the week' configuration
        #wday returns 0 - 6, 0 is sunday
        startOfWeek = getStartOfWeek

        # index = (entry.spent_on.wday+7-(startOfWeek))%7
        index = (entry.spent_on.to_date - end_date.to_date).to_i
        updated = false
        hourMatrix.each do |rows|
          if rows[index].blank?
            rows[index] = entry
            updated = true
            break
          else
            if sumHours
              tempEntry = rows[index]
              tempEntry.hours += entry.hours
              updated = true
              break
            end
          end
        end
        if !updated
          rows = []
          hourMatrix[hourMatrix.size] = rows
          rows[index] = entry
        end
      end
    end
    return weeklyHash
  end


  def check_l3_status_for_month_project(select_time,user,project_id,startday,end_day)
    # startday = select_time.to_date.beginning_of_month
    # end_day = select_time.to_date.end_of_month
    work_days = []
    l3_dates = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      else
        work_days << day
        l3_date  = Wktime.where(begin_date: day,status: "l3",:user_id=>user,:project_id=> project_id)
        if l3_date.present?
          l3_dates << day
        end
      end
    end
    # if l3_dates.present? && l3_dates.count >= work_days.count
    #   return true
    # else
    #   return  false
    # end
    if l3_dates.present? && l3_dates.count >= 1 && l3_dates.count != work_days.count
      return "true_false"
    elsif l3_dates.present? && l3_dates.count == work_days.count
      return  true
    else
      return false
    end
  end

  def check_box_status(user,project_id,startday,end_day)
    approve_l2_dates = Wktime.where(begin_date: (startday..end_day),status: "l2",:user_id=>user,:project_id=> project_id)
    approve_l3_dates = Wktime.where(begin_date: (startday..end_day),status: "l3",:user_id=>user,:project_id=> project_id)
    if approve_l2_dates.present? && approve_l2_dates.count == ((end_day-startday).to_i + 1)
      return "home_l2"
    elsif approve_l3_dates.present? && approve_l3_dates.count == ((end_day-startday).to_i + 1)
      return "l3"
    end
  end

  def check_l2_status_for_month_project(select_time,user,project_id,startday,end_day)
    work_days = (startday..end_day).count
    #l2_approve_count = []
    #(startday..end_day).each do |day|
      #if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      #else
        # work_days << day
        l2_date  = Wktime.where(begin_date: (startday..end_day),status: "l2",:user_id=>user,:project_id=> project_id)
        #if l2_date.present?
          l2_approve_count =  l2_date.count
        #end
      #end
    #end
    if l2_approve_count.present? && l2_approve_count >= 1 && l2_approve_count != work_days
      return "true_false"
    elsif l2_approve_count.present? && l2_approve_count == work_days
      return  true
    else
      return false
    end

  end


  def get_user_name(user_id)
    user = User.find(user_id)
    if user.present?
      return user.firstname
    end
  end

  def get_emp_id(user_id)
    user = User.find(user_id)
    # user.custom_field_values.each_with_index do |c,index|
    #   custom_field =CustomField.where(:id=>c.custom_field_id)
    #   if custom_field.present? && (custom_field.last.name=="Emp_code")
    #     p user.custom_field_values[index]
    #     p user.custom_field_values[index].to_s
    #   end
    # end
    if user.user_official_info.present? && user.user_official_info.employee_id.present?
        user.user_official_info.employee_id.to_s
    end

  end

  def check_l2_status_for_month(select_time,user)
    startday = select_time.to_date.beginning_of_month
    end_day = select_time.to_date.end_of_month
    work_days = []
    l2_dates = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      else
        work_days << day
        l2_date  = Wktime.where(begin_date: day,status: "l2",:user_id=>user)
        if l2_date.present?
          l2_dates << day
        end
      end
    end
    if l2_dates.present?
      return true
    else
      return  false
    end
  end
  def check_l3_status_for_month(select_time,user,project_id)
    startday = select_time.to_date.beginning_of_month
    end_day = select_time.to_date.end_of_month
    work_days = []
    l3_dates = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      else
        work_days << day
        l3_date  = Wktime.where(begin_date: day,status: "l3",:user_id=>user,:project_id=> project_id)
        if l3_date.present?
          l3_dates << day
        end
      end
    end
    if l3_dates.present? && l3_dates.count >= work_days.count
      return true
    else
      return  false
    end
  end

  def check_project_permission(ids, l)
    projects = Project.find(ids)
    members = []
    permissions = []
    projects.each { |rec| members << rec.member_principals.find_by_user_id(User.current.id)  } if projects.kind_of?(Array)
    members << projects.member_principals.find_by_user_id(User.current.id) if !projects.kind_of?(Array)
    members.flatten.each do |rec|
      rec.member_roles.each { |rec| permissions << rec.role.permissions } if rec.present?
    end
    if permissions.flatten.present? && (permissions.flatten.include?(l.to_sym) || permissions.flatten.include?(l.to_sym))
      return true
    else
      return false
    end
  end

  def accessable_projects(ids, l)
    projects = Project.find(ids)
    ids = []
    members = []
    permissions = []
    projects.each { |project| members << project.member_principals.find_by_user_id(User.current.id)
    members.flatten.each do |rec1|
      rec1.member_roles.each { |rec| permissions << rec.role.permissions
      if permissions.flatten.present? && (permissions.flatten.include?(l.to_sym) || permissions.flatten.include?(l.to_sym))
        ids << project.id
      end
      } if rec1.present?
    end
    }
    ids
  end


  # def get_emmetric_hours(user_id,date)
  #   @user_emp_code=''
  #   user = User.find(user_id)
  #   user.custom_field_values.each_with_index do |c,index|
  #     custom_field =CustomField.where(:id=>c.custom_field_id)
  #     if custom_field.present? && (custom_field.last.name=="Emp_code")
  #       @user_emp_code = user.custom_field_values[index].to_s
  #     end
  #   end
  #   user_date = date.to_date.strftime('%d%m%Y')
  #   bio_user="inia"
  #   bio_password="4plgI}1P"
  #   url = "http://biometrics.objectfrontier.com/cosec/api.svc/attendance-daily?action=get;id="+@user_emp_code+";range=user;date-range="+user_date+"-"+user_date+";field-name=WORKTIME_HHMM;format=xml"
  #   #url1 = "http://biometrics.objectfrontier.com/cosec/api.svc/attendance-daily?action=get;id=1104;date-range=17112014-17112014;range=user;format=text"

  #   #url1 = "http://biometrics.objectfrontier.com/cosec/api.svc/attendance-daily?action=get;id=1104;date-range=17112014-17112014;field-name=WORKTIME_HHMM;range=user;format=xml"
  #   if @user_emp_code.present?
  #     response = RestClient::Request.new(:method => :get,:url => url,:user => bio_user,:password => bio_password).execute
  #     #response1 = RestClient::Request.new(:method => :get,:url => url1,:user => bio_user,:password => bio_password).execute
  #     nokogiri_xml1 =Nokogiri::HTML::Document.parse(response.body)

  #     if response.present?
  #       nokogiri_xml =Nokogiri::HTML::Document.parse(response.body)
  #       nokogiri_xml_attendance = nokogiri_xml.css('attendance-daily') if nokogiri_xml.present?
  #       nokogiri_xml_attendance.map(&:text)[0]
  #       result=nokogiri_xml_attendance.map(&:text)[0] if nokogiri_xml_attendance.map(&:text)[0].present?
  #       return result
  #     end
  #   end
  # end

  def get_biometric_hours_per_month(users,date,enddate,month_or_week)
    user_emp_code = []
     users = users.kind_of?(Array) ? users : [users]
     emp_info = Redmine::Plugin.registered_plugins.keys.include?(:employee_info)
     users.flatten.each do |user|
       if emp_info && user.user_official_info.present? && user.user_official_info.employee_id.present?
         user_emp_code << user.user_official_info.employee_id
       else
         user_emp_code << ""
       end
    #   user.custom_field_values.each_with_index do |c,index|
    #     custom_field =CustomField.where(:id=>c.custom_field_id)
    #     if custom_field.present? && (custom_field.last.name=="Emp_code")
    #       user_emp_code << user.custom_field_values[index].to_s
    #     end
    #   end
     end
    user_emp_code.delete('')
    user_emp_code.delete(0)
    user_emp_code = user_emp_code.uniq.join(",")
    if month_or_week == "from_to_end"
      start_date = date.to_date.strftime('%Y-%m-%d')
      end_date = enddate.to_date.strftime('%Y-%m-%d')
    elsif month_or_week=="week"
      start_date = date.to_date.strftime('%Y-%m-%d')
      end_date = (date + 6).to_date.strftime('%Y-%m-%d')
    end
    if user_emp_code.present?
      key = Redmine::Configuration['iServ_api_key']
      base_url = Redmine::Configuration['iServ_url']
      url1 = base_url+"/services/employees/dailyattendance/#{user_emp_code}?fromDate=#{start_date}&toDate=#{end_date}"
      begin
        response = RestClient::Request.new(:method => :get,:url => url1, :headers => {:"Auth-key" => key},:verify_ssl => false).execute 
      rescue => e
        response = 'failed'
      end
      user_array = user_emp_code.split(',')
      my_arrays = {}
      result =[]

      if (!response.include?('failed') && !response.include?('No records found')) && response.present?
        data = JSON.parse(response)
        user_array.each_with_index { |name, index| my_arrays[name] = {}   }
        if data['attendance-daily'].count > 1
          user_array.each_with_index  do |id, index|
            data['attendance-daily'].each do |rec|
              if rec['userid'] == id
                my_arrays[id].merge!(rec['processdate'] => rec['worktime_hhmm'])
              end
            end
          end
          return my_arrays
        else
          {}
        end
      end
    end

  end


  def check_bio_permission_list_user_id_project_id(l,user_id,project_ids)
    @all_roles=[]

    #user = User.find_by_id(user_id)
    if !project_ids.present?
      project_ids = [User.current.projects.first.id]
    end
    #project = Project.where(id:project_2).last

    project_ids.each do |project_id|
      project = Project.find_by_id(project_id)
      logtime_projects = User.current.roles_for_project(project)
      if logtime_projects.present?
        logtime_projects.each do |each_role|
          if !@all_roles.present? && each_role.permissions.index(l.to_sym)

            @all_roles << each_role.permissions
          end
        end

      end
    end

    @all_roles = @all_roles.flatten! if @all_roles.present?


    if (Setting.plugin_redmine_wktime[:wktime_own_approval].blank? && user_id.to_i == User.current.id)
      @all_roles =[]
    end
    if @all_roles.present?
      if (l == "l1")
        check_l1 = @all_roles.include? l.to_sym
        check_l2 = @all_roles.include? "l2".to_sym
        if check_l1.present? && !check_l2.present?
          return true
        end
      elsif(l == "l2")
        if @all_roles.include? l.to_sym
          return true
        end
      elsif(l == "l3")
        if @all_roles.include? l.to_sym
          return true
        end
      elsif(l == "bio_hours_display")

        if @all_roles.include? l.to_sym
          return true
        end
      end
    else
    end
  end


  def found_issues(current_issues,entry)

    curr_issue_found = false
    issues = Array.new
    if !Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].blank? &&
        Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].to_i == 1
      # add an empty issue to the array
      issues << [ "", ""]
    end
    allIssues = current_issues
    unless allIssues.blank?
      allIssues.each do |i|
        #issues << [ i.id.to_s + ' - ' + i.subject, i.id ]
        #issues << [ i.to_s , i.root_id ]
        issues << [ i.tracker.name + " #"+i.root_id.to_s+': ' + i.subject, i.root_id ]
        curr_issue_found = true if !entry.nil? && i.root_id == entry.issue_id
      end
    end
    #check if the issue, which was previously reported time, is still visible
    #if it is not visible, just show the id alone
    if !curr_issue_found
      if !entry.nil?
        if !entry.issue_id.nil?
          # issues.unshift([ entry.issue_id, entry.issue_id ])
          issues << [ entry.issue.tracker.name + " #"+entry.issue.root_id.to_s+': ' + entry.issue.subject, entry.issue.root_id ]
        else
          if Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].blank? ||
              Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].to_i == 0
            # add an empty issue to the array, if it is not already there
            issues.unshift([ "", ""])
          end
        end
      end
    end

    return issues
  end

 def found_activities(projActList,entry)

    activity = nil
    activities = nil
    #projActList = @projActivities[project_id]
    #activities = activities.sort_by{|name, id| name} unless activities.blank?
    unless projActList.blank?
      projActList = projActList.sort_by{|name| name}

      activity = projActList.detect {|a| a.id == entry.activity_id} unless entry.nil?
      #check if the activity, which was previously reported time, is still visible
      #if it is not visible, just show the id alone

      activities = projActList.collect {|a| [a.name, a.id]}
      activities.unshift( [ entry.activity_id, entry.activity_id ] )if !entry.nil? && activity.blank?

    end

    return activities

  end


  def get_project_id(entry)
    entry.nil? ? (@logtime_projects.blank? ? 0 : @logtime_projects[0].id) : entry.project_id
  end
  # def find_projects(entry)
  #   projects.detect {|p| p[1].to_i == entry.project_id} unless entry.nil?
  #
  # end
  def find_projects(entry)
    projects = options_for_wktime_project(@logtime_projects)
    project = projects.detect {|p| p[1].to_i == entry.project_id} unless entry.nil?
    #check if the project, which was previously reported time, is still visible
    #if it is not visible, just show the id alone
    projects.unshift( [ entry.project_id, entry.project_id ] ) if !entry.nil? && project.blank?
    return projects
  end


  def find_current_issues(entry,projectissues,project_id)
    curr_issue_found = false
    issues = Array.new
    if !Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].blank? &&
        Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].to_i == 1
      # add an empty issue to the array
      issues << [ "", ""]
    end
    allIssues = projectissues[project_id]
    unless allIssues.blank?
      allIssues.each do |i|
        #issues << [ i.id.to_s + ' - ' + i.subject, i.id ]
        issues << [ i.to_s , i.id ]
        curr_issue_found = true if !entry.nil? && i.id == entry.issue_id
      end
    end
    #check if the issue, which was previously reported time, is still visible
    #if it is not visible, just show the id alone
    if !curr_issue_found
      if !entry.nil?
        if !entry.issue_id.nil?
          issues.unshift([ entry.issue_id, entry.issue_id ])
        else
          if Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].blank? ||
              Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].to_i == 0
            # add an empty issue to the array, if it is not already there
            issues.unshift([ "", ""])
          end
        end
      end
    end
    return issues

  end

  def find_current_activities(entry,projActivities,project_id)
    activity = nil
    activities = nil
    projActList = projActivities[project_id]
    #activities = activities.sort_by{|name, id| name} unless activities.blank?
    unless projActList.blank?
      projActList = projActList.sort_by{|name| name}

      activity = projActList.detect {|a| a.id == entry.activity_id} unless entry.nil?
      #check if the activity, which was previously reported time, is still visible
      #if it is not visible, just show the id alone

      activities = projActList.collect {|a| [a.name, a.id]}
      activities.unshift( [ entry.activity_id, entry.activity_id ] )if !entry.nil? && activity.blank?
    end
    return activities
  end

  def get_project_ids(entries)
    entries.present? ? entries.map(&:project_id).uniq : [@logtime_projects.first.id]
  end

  def synch_database

    connection1 = ActiveRecord::Base.establish_connection(
        :adapter  => "mysql2",
        :host     => "192.168.9.104",
        :username => "root",
        :password => "root",
        :database => "redmine_synch_from"
    ).connection

    tables = connection1.tables

    @errors=[]
    @errors1=[]
    want_tables = ["projects"]

    if tables.present?
      # tables = skip_tables - tables
      tables.each do |each_table|
        begin
          connection1.execute("REPLACE into redmine_synch_to.#{each_table} select * from redmine_synch_from.#{each_table} ")
        rescue Exception => e
          @errors<< each_table
          @errors1<< {each_table=> e}
          next
        end
      end

    end

  end



  def remove_duplicates(entry)
    find_entries = TimeEntry.where(:project_id=>entry.project_id,:user_id=>entry.user_id,:issue_id=>entry.issue_id,:activity_id=>entry.activity_id,:spent_on=>entry.spent_on)
    sum = find_entries.map{|a| a.hours }.sum.to_i
    concat_comments = find_entries.collect(&:comments).uniq.join(' ')
    find_entries.shift.update_attributes(:hours=>sum,:comments=> concat_comments)
    find_entries.map{|entry| entry.delete } if find_entries.present?
  end


  def set_approved_color(value, th, user_id)
    if value[1].present? && value[1].include?(th.to_date)
      'l3_approved'
    elsif value[2].present? && value[2].include?(th.to_date)
      'l2_approved'
    elsif value[3].present? && value[3].include?(th.to_date)
      'l1_approved'
    elsif value[4].present? && value[4].include?(th.to_date)
      'reject_approval'
    #elsif !check_time_log_entry(th.to_date,User.find(user_id))
     # 'lock_entry'
    end

  end

end
