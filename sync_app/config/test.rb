require 'csv'
class Sync < ActiveRecord::Base


  def self.sync_sql


    hrms_sync_details={"adapter"=>ActiveRecord::Base.configurations['hrms_user_sync']['adapter_sync'], "database"=>ActiveRecord::Base.configurations['hrms_user_sync']['database_sync'], "host"=>ActiveRecord::Base.configurations['hrms_user_sync']['host_sync'], "port"=>ActiveRecord::Base.configurations['hrms_user_sync']['port_sync'], "username"=>ActiveRecord::Base.configurations['hrms_user_sync']['username_sync'], "password"=>ActiveRecord::Base.configurations['hrms_user_sync']['password_sync'], "encoding"=>ActiveRecord::Base.configurations['hrms_user_sync']['encoding_sync']}

    inia_database_details = {"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}

    AppSyncInfo.establish_connection(inia_database_details)
    rec = AppSyncInfo.find_or_initialize_by_name('hrms')
    rec.in_progress = true
    if !rec.last_sync.present?
      rec.last_sync=Time.now
      @sync_time = (Time.now - 1.minute)
    else
      @sync_time = (rec.last_sync-1.minute)
    end
    rec.save
    #===================================================================================
    #================= user =============================
    Rails.logger.info "-- User -$$$$$$$$$$$$$$$$$-"
    hrms =  ActiveRecord::Base.establish_connection(hrms_sync_details).connection
    user_data = "SELECT first_name, last_name, login_id, work_email, employee_no, is_active, modified_date, prev_emp_no FROM vw_employee where modified_date >= '#{@sync_time}' and employee_no != 0 and work_email != '' and login_id !='' "
    user_query =  user_data
    @user_info = hrms.execute(user_query)
    hr_user_count = hrms.execute("select * from employee")
    Rails.logger.info " Total users in HRMS : #{hr_user_count.count}"
    Rails.logger.info " Sync users from HRMS : #{@user_info.count}"
    hrms.disconnect!
    inia =  ActiveRecord::Base.establish_connection(:production).connection
    inia_users = inia.execute("select * from users where type='User' and status=1")
    Rails.logger.info " Total users in iNia before Sync : #{inia_users.count}"

    # Rails.logger.info "-------- 123 ----------------"
    @user_info.each(:as => :hash) do |user|
      final_sql = "INSERT into users(login, firstname, lastname, mail, language, auth_source_id, created_on, hashed_password, status, last_login_on, type, identity_url, mail_notification, salt,  must_change_passwd, passwd_changed_on, lastmodified) VALUES ('#{user['login_id']}', '#{user['first_name']}','#{user['last_name']}','#{user['work_email']}','en',1, NOW(),'','#{user['is_active']==1 ? 1 : 3}',NULL,'User', NULL,'only_my_events',NULL,false,NULL,NOW())"

      emp_code_con = "select * from user_official_infos where employee_id=#{user['employee_no']}"

      last_emp_code_nanba = "INSERT into user_official_infos (user_id, employee_id) values ((select id from users where login='#{user['login_id']}' limit 1) ,#{user['employee_no']})ON DUPLICATE KEY UPDATE employee_id=VALUES(employee_id),user_id=VALUES(user_id)"
      last_emp_code = "INSERT into user_official_infos (user_id, employee_id, department,location_name,region_name,location_type) values ('#{row["user_id"].to_i}',#{user['employee_no']},'#{user['dep_name']}','#{user['loc_name']}','#{user['region_name']}','#{user['location_type']}')"


      update_sql = "update users set login='#{user['login_id']}',firstname='#{user['first_name']}',lastname='#{user['last_name']}',mail='#{user['work_email']}',language='en', auth_source_id=1, status='#{user['is_active']==1 ? 1 : 3}',type='User', salt=NULL ,lastmodified=NOW() where id=(select user_id from user_official_infos where employee_id=#{user['employee_no']} limit 1)"
      res1 =  inia.execute(emp_code_con)

      emp_up_nanba = "update user_official_infos set user_id=(select id from users where login='#{user['login_id']}' limit 1) where employee_id=#{user['employee_no']}"

      emp_up = "UPDATE user_official_infos SET employee_id=#{user['employee_no']},department='#{user['dep_name']}',location_name='#{user['loc_name']}',region_name='#{user['region_name']}',location_type='#{user['location_type']}' where user_id=(select id from users where login='#{user['login_id']}' limit 1)"


      user_count =  inia.execute("select id from users where login='#{user['login_id']}'")

      if res1.count==0 && user_count.count==0 && user['prev_emp_no'].nil?
        Rails.logger.info "--- insert  - #{user['login_id']} - users ---"
        inia.execute(final_sql)
        user_id = User.find_by_login(user['login_id']).id rescue nil
        lemp_code = "INSERT into user_official_infos (user_id, employee_id) values (#{user_id} ,#{user['employee_no']})ON DUPLICATE KEY UPDATE employee_id=VALUES(employee_id),user_id=VALUES(user_id)"
        inia.execute(lemp_code)
      elsif user['prev_emp_no'].nil?
        Rails.logger.info "--- update - #{user['login_id']} - users ---"
        if res1.count == 0 && user['is_active']==1
          inia.execute(last_emp_code)
        else
          inia.execute(emp_up)
        end
        inia.execute(update_sql)
        #====================================
      end
      if user['prev_emp_no'].present?
        Rails.logger.info '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$   transfer $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
        User.establish_connection(:production)
        UserOfficialInfo.establish_connection(:production)
        uoi = UserOfficialInfo.find_by_employee_id(user['prev_emp_no'])
        if uoi.present?
          usr = uoi.user
          if usr.nil?
            usr = User.find_by_login(user['login_id'])
            uoi.user_id = usr.id
          end
          usr.firstname=user['first_name']
          usr.lastname=user['last_name']
          usr.login=user['login_id']
          usr.mail=user['work_email']
          usr.status =user['is_active']==1 ? 1 : 3
          usr.save
          uoi.employee_id = user['employee_no']
          uoi.save rescue false
          Rails.logger.info uoi.errors
        end
      end
    end
    inia_users_count = inia.execute("select * from users where type='User' and status=1")
    Rails.logger.info " Total users in iNia after Sync : #{inia_users_count.count}"
    #================= user =============================
    #===================================================================================
  end




  def self.sync_sql_with_login


    hrms_sync_details={"adapter"=>ActiveRecord::Base.configurations['hrms_user_sync']['adapter_sync'], "database"=>ActiveRecord::Base.configurations['hrms_user_sync']['database_sync'], "host"=>ActiveRecord::Base.configurations['hrms_user_sync']['host_sync'], "port"=>ActiveRecord::Base.configurations['hrms_user_sync']['port_sync'], "username"=>ActiveRecord::Base.configurations['hrms_user_sync']['username_sync'], "password"=>ActiveRecord::Base.configurations['hrms_user_sync']['password_sync'], "encoding"=>ActiveRecord::Base.configurations['hrms_user_sync']['encoding_sync']}

    inia_database_details = {"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}

    AppSyncInfo.establish_connection(inia_database_details)
    rec = AppSyncInfo.find_or_initialize_by_name('hrms')
    rec.in_progress = true
    if !rec.last_sync.present?
      rec.last_sync=Time.now
      @sync_time = (Time.now - 1.minute)
    else
      @sync_time = (rec.last_sync-1.minute)
    end
    rec.save
# hrms_connection =  ActiveRecord::Base.establish_connection(:hrms_sync_details)
    hrms =  ActiveRecord::Base.establish_connection(hrms_sync_details).connection
# @user_info = hrms.execute("SELECT a.first_name, a.last_name, b.login_id,c.work_email, c.employee_no FROM hrms.employee a, hrms.user b, hrms.official_info c where b.id=a.user_id and a.id=c.employee_id and a.modified_date >= '#{@sync_time}'")
#   @user_info = hrms.execute("SELECT a.first_name, a.last_name, b.login_id,b.is_active,c.work_email, c.employee_no FROM employee a, user b, official_info c where b.id=a.user_id and a.id=c.employee_id and a.modified_date >= '#{@sync_time}'")
    @user_info = hrms.execute("SELECT * FROM vw_employee where employee_no !=0 and employee_no != '' and login_id != '' and work_email !='' and login_id !='' and modified_date <= '#{Time.now}';")
    inia =  ActiveRecord::Base.establish_connection(:production).connection


    @user_info.each(:as => :hash) do |user|

      # find_user_with_employee_id = "select * from user_official_infos where user_official_infos.employee_id='#{user['employee_no']}'"
      find_user_with_login_id = "select * from users where users.login='#{user['login_id']}'"

      find_user_with_employee = inia.execute(find_user_with_login_id)

      if find_user_with_employee.count == 0

        if user['prev_emp_no'].present?
          find_previous_employee_id = "select * from user_official_infos where user_official_infos.employee_id='#{user['prev_emp_no']}'"
          find_user_with_employee = inia.execute(find_previous_employee_id)

          if find_user_with_employee.count != 0

            find_user_with_employee.each(:as => :hash) do |row|
              user_update_query = "UPDATE users SET login='#{user['login_id']}',firstname='#{user['first_name']}',lastname='#{user['last_name']}'
          ,mail='#{user['work_email']}',auth_source_id=1,status='1',updated_on=NOW() where id='#{row["user_id"]}'"
              update_employee = inia.execute(user_update_query)

              find_user_with_employee_id = "select * from user_official_infos where user_official_infos.employee_id='#{row['user_id']}'"
              find_user_with_employee_id = inia.execute(find_user_with_employee_id)
              if find_user_with_employee_id.count ==0
                user_info_query = "INSERT into user_official_infos (user_id, employee_id, department,location_name,region_name,location_type) values ('#{row["user_id"].to_i}',#{user['employee_no']},'#{user['dep_name']}','#{user['loc_name']}','#{user['region_name']}','#{user['location_type']}')"
                save_employee = inia.insert_sql(user_info_query)
              else

                update_user_official_info = "UPDATE user_official_infos SET employee_id=#{user['employee_no']},department='#{user['dep_name']}',location_name='#{user['loc_name']}',region_name='#{user['region_name']}',location_type='#{user['location_type']}' where user_id=#{row["id"]}"
                save_employee = inia.execute(update_user_official_info)
              end

            end
          end

        else

          user_insert_query = "INSERT into users(login,firstname,lastname,mail,auth_source_id,created_on,status,type,updated_on)
      VALUES ('#{user['login_id']}','#{user['first_name']}','#{user['last_name']}','#{user['work_email']}',1, NOW(),'#{user['is_active'].present? && user['is_active']==1 ? user['is_active'].to_i : 3}','User',NOW())"

          save_user = inia.insert_sql(user_insert_query)
          user_info_query = "INSERT into user_official_infos (user_id, employee_id, department,location_name,region_name,location_type) values ('#{save_user.to_i}',#{user['employee_no']},'#{user['dep_name']}','#{user['loc_name']}','#{user['region_name']}','#{user['location_type']}')"
          save_employee = inia.insert_sql(user_info_query)

        end

      else

        find_user_with_employee.each(:as => :hash) do |row|
          user_update_query = "UPDATE users SET login='#{user['login_id']}',firstname='#{user['first_name']}',lastname='#{user['last_name']}'
          ,mail='#{user['work_email']}',auth_source_id=1,status='#{ user['is_active'].present? && user['is_active']==1 ? user['is_active'].to_i : 3 }',updated_on=NOW() where id='#{row["id"]}'"
          update_employee = inia.execute(user_update_query)

          find_user_with_employee_id1 = "select * from user_official_infos where user_official_infos.user_id='#{row["id"]}'"
          find_user_with_employee_id = inia.execute(find_user_with_employee_id1)

          p find_user_with_employee_id
          if find_user_with_employee_id.count ==0

            user_info_query = "INSERT into user_official_infos (user_id, employee_id, department,location_name,region_name,location_type) values ('#{row["id"].to_i}',#{user['employee_no']},'#{user['dep_name']}','#{user['loc_name']}','#{user['region_name']}','#{user['location_type']}')"
            save_employee = inia.insert_sql(user_info_query)
          else


            update_user_official_info = "UPDATE user_official_infos SET employee_id=#{user['employee_no']},department='#{user['dep_name']}',location_name='#{user['loc_name']}',region_name='#{user['region_name']}',location_type='#{user['location_type']}' where user_id=#{row["id"]}"
            save_employee = inia.execute(update_user_official_info)
          end

        end

      end

      rec.update_attributes(:last_sync=>Time.now)
    end


  end



  def self.sync_exist_sql


    hrms_sync_details={"adapter"=>ActiveRecord::Base.configurations['hrms_user_sync']['adapter_sync'], "database"=>ActiveRecord::Base.configurations['hrms_user_sync']['database_sync'], "host"=>ActiveRecord::Base.configurations['hrms_user_sync']['host_sync'], "port"=>ActiveRecord::Base.configurations['hrms_user_sync']['port_sync'], "username"=>ActiveRecord::Base.configurations['hrms_user_sync']['username_sync'], "password"=>ActiveRecord::Base.configurations['hrms_user_sync']['password_sync'], "encoding"=>ActiveRecord::Base.configurations['hrms_user_sync']['encoding_sync']}

    inia_database_details = {"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}

    AppSyncInfo.establish_connection(inia_database_details)
    rec = AppSyncInfo.find_or_initialize_by_name('hrms')
    rec.in_progress = true
    if !rec.last_sync.present?
      rec.last_sync=Time.now
      @sync_time = (Time.now - 1.minute)
    else
      @sync_time = (rec.last_sync-1.minute)
    end
    rec.save
# hrms_connection =  ActiveRecord::Base.establish_connection(:hrms_sync_details)
    hrms =  ActiveRecord::Base.establish_connection(hrms_sync_details).connection
# @user_info = hrms.execute("SELECT a.first_name, a.last_name, b.login_id,c.work_email, c.employee_no FROM hrms.employee a, hrms.user b, hrms.official_info c where b.id=a.user_id and a.id=c.employee_id and a.modified_date >= '#{@sync_time}'")
#   @user_info = hrms.execute("SELECT a.first_name, a.last_name, b.login_id,b.is_active,c.work_email, c.employee_no FROM employee a, user b, official_info c where b.id=a.user_id and a.id=c.employee_id and a.modified_date >= '#{@sync_time}'")
    @user_info = hrms.execute("SELECT * FROM vw_employee where employee_no !=0 and employee_no != '' and login_id != '' and work_email !='' and login_id !='' and modified_date <= '#{Time.now}';")
    inia =  ActiveRecord::Base.establish_connection(:production).connection


    @user_info.each(:as => :hash) do |user|

      # find_user_with_employee_id = "select * from user_official_infos where user_official_infos.employee_id='#{user['employee_no']}'"
      # find_user_with_login_id = "select * from users where users.login='#{user['login_id']}'"

      # find_user_with_employee = inia.execute(find_user_with_login_id)

      find_user_with_employee_id = "select * from user_official_infos where user_official_infos.employee_id='#{user['employee_no']}'"
      find_user_with_employee = inia.execute(find_user_with_employee_id)


      if find_user_with_employee.count == 0

        if user['prev_emp_no'].present?
          find_previous_employee_id = "select * from user_official_infos where user_official_infos.employee_id='#{user['prev_emp_no']}'"
          find_user_with_employee = inia.execute(find_previous_employee_id)

          if find_user_with_employee.count != 0

            find_user_with_employee.each(:as => :hash) do |row|
              user_update_query = "UPDATE users SET login='#{user['login_id']}',firstname='#{user['first_name']}',lastname='#{user['last_name']}'
          ,mail='#{user['work_email']}',auth_source_id=1,status='1',updated_on=NOW() where id='#{row["user_id"]}'"
              update_employee = inia.execute(user_update_query)

              find_user_with_employee_id = "select * from user_official_infos where user_official_infos.employee_id='#{row['user_id']}'"
              find_user_with_employee_id = inia.execute(find_user_with_employee_id)
              if find_user_with_employee_id.count ==0
                user_info_query = "INSERT into user_official_infos (user_id, employee_id, department,location_name,region_name,location_type) values ('#{row["user_id"].to_i}',#{user['employee_no']},'#{user['dep_name']}','#{user['loc_name']}','#{user['region_name']}','#{user['location_type']}')"
                save_employee = inia.insert_sql(user_info_query)
              else

                update_user_official_info = "UPDATE user_official_infos SET employee_id=#{user['employee_no']},department='#{user['dep_name']}',location_name='#{user['loc_name']}',region_name='#{user['region_name']}',location_type='#{user['location_type']}' where user_id=#{row["id"]}"
                save_employee = inia.execute(update_user_official_info)
              end

            end
          end

        else

          user_insert_query = "INSERT into users(login,firstname,lastname,mail,auth_source_id,created_on,status,type,updated_on)
      VALUES ('#{user['login_id']}','#{user['first_name']}','#{user['last_name']}','#{user['work_email']}',1, NOW(),'#{user['is_active'].present? && user['is_active']==1 ? user['is_active'].to_i : 3}','User',NOW())"
          save_user = inia.insert_sql(user_insert_query)
          user_info_query = "INSERT into user_official_infos (user_id, employee_id, department,location_name,region_name,location_type) values ('#{save_user.to_i}',#{user['employee_no']},'#{user['dep_name']}','#{user['loc_name']}','#{user['region_name']}','#{user['location_type']}')"
          save_employee = inia.insert_sql(user_info_query)

        end

      else

        find_user_with_employee.each(:as => :hash) do |row|
          user_update_query = "UPDATE users SET login='#{user['login_id']}',firstname='#{user['first_name']}',lastname='#{user['last_name']}'
          ,mail='#{user['work_email']}',auth_source_id=1,status='#{ user['is_active'].present? && user['is_active']==1 ? user['is_active'].to_i : 3 }',updated_on=NOW() where id='#{row["user_id"]}'"
          update_employee = inia.execute(user_update_query)

          # find_user_with_employee_id1 = "select * from user_official_infos where user_official_infos.user_id='#{row["user_id"]}'"
          # find_user_with_employee_id = inia.execute(find_user_with_employee_id1)

          # p find_user_with_employee_id
          # if find_user_with_employee_id.count ==0
          #
          #   user_info_query = "INSERT into user_official_infos (user_id, employee_id) values ('#{row["id"]}',#{user['employee_no']})"
          #   save_employee = inia.insert_sql(user_info_query)
          # else
          #
          #
          #   update_user_official_info = "UPDATE user_official_infos SET employee_id=#{user['employee_no']} where user_id=#{row["id"]}"
          #   save_employee = inia.execute(update_user_official_info)
          # end

        end

      end

      rec.update_attributes(:last_sync=>Time.now)
    end


  end



  def self.make_users_inactive

    # hrms_sync_details={"adapter"=>ActiveRecord::Base.configurations['hrms_user_sync']['adapter_sync'], "database"=>ActiveRecord::Base.configurations['hrms_user_sync']['database_sync'], "host"=>ActiveRecord::Base.configurations['hrms_user_sync']['host_sync'], "port"=>ActiveRecord::Base.configurations['hrms_user_sync']['port_sync'], "username"=>ActiveRecord::Base.configurations['hrms_user_sync']['username_sync'], "password"=>ActiveRecord::Base.configurations['hrms_user_sync']['password_sync'], "encoding"=>ActiveRecord::Base.configurations['hrms_user_sync']['encoding_sync']}
    #
    # inia_database_details = {"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}
    inia =  ActiveRecord::Base.establish_connection(:production).connection
    all_users = inia.execute("select * from users Where type='User'")

    all_users.each(:as => :hash) do |user|

      user_update_query = "UPDATE users SET login='#{user['login']}',firstname='#{user['firstname']}',lastname='#{user['lastname']}'
          ,mail='#{user['mail']}',auth_source_id=1,status='3',updated_on=NOW() where login='#{user['login']}'"

      update_user = inia.execute(user_update_query)

    end
  end


  def self.extra_users_list

    hrms_sync_details={"adapter"=>ActiveRecord::Base.configurations['hrms_user_sync']['adapter_sync'], "database"=>ActiveRecord::Base.configurations['hrms_user_sync']['database_sync'], "host"=>ActiveRecord::Base.configurations['hrms_user_sync']['host_sync'], "port"=>ActiveRecord::Base.configurations['hrms_user_sync']['port_sync'], "username"=>ActiveRecord::Base.configurations['hrms_user_sync']['username_sync'], "password"=>ActiveRecord::Base.configurations['hrms_user_sync']['password_sync'], "encoding"=>ActiveRecord::Base.configurations['hrms_user_sync']['encoding_sync']}
    inia_database_details = {"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}
    rec = AppSyncInfo.find_or_initialize_by_name('hrms')


    hrms =  ActiveRecord::Base.establish_connection(hrms_sync_details).connection
    @user_info = hrms.execute("SELECT a.first_name, a.last_name, b.login_id,c.work_email, c.employee_no,b.is_active FROM employee a, user b, official_info c where b.id=a.user_id and a.id=c.employee_id and a.modified_date <= '#{Time.now}'")
    hrms.disconnect!
    inia =  ActiveRecord::Base.establish_connection(:production).connection
    @user_info.each(:as => :hash) do |user|

      find_user = "select * from users where users.login='#{user['login_id']}'"
      find_user_res =  inia.execute(find_user)


    end
  end


  def self.from_csv

    require 'spreadsheet'

    book = Spreadsheet.open '/home/developer/Desktop/redmine/Employee_Info_11-Jan.xls'
    inia =  ActiveRecord::Base.establish_connection(:production).connection
    inia_database_details = {"adapter"=>'mysql2', "database"=>'nanba2', "host"=>'127.0.0.1', "port"=>'3306', "username"=>'root', "password"=>'root'}
    sheet1 = book.worksheet 0
    sheet2 = book.worksheet 'Sheet1'
    sheet1.each do |row|
      p row[0]
      p row[1]
      # do something interesting with a row
    end
  end



  def self.to_csv(options = {})
    column_names = []
    CSV.generate(options) do |csv|
      csv << column_names
      all.each do |product|
        csv << product.attributes.values_at(*column_names)
      end
    end
  end


end
