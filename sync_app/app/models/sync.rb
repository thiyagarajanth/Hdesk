class Sync < ActiveRecord::Base
  def self.sync_sql(options = {})

    sync_details={"adapter"=>ActiveRecord::Base.configurations['sync_prod']['adapter_sync'], "database"=>ActiveRecord::Base.configurations['sync_prod']['database_sync'], "server"=>ActiveRecord::Base.configurations['sync_prod']['server_sync'], "host"=>ActiveRecord::Base.configurations['sync_prod']['host_sync'], "port"=>ActiveRecord::Base.configurations['sync_prod']['port_sync'], "username"=>ActiveRecord::Base.configurations['sync_prod']['username_sync'], "password"=>ActiveRecord::Base.configurations['sync_prod']['password_sync'], "encoding"=>ActiveRecord::Base.configurations['sync_prod']['encoding_sync']}

    sync_details_development={"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "server"=>ActiveRecord::Base.configurations['development']['server'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}

    hrms_sync_details={"adapter"=>ActiveRecord::Base.configurations['hrms_user_sync']['adapter_hrms_sync'], "database"=>ActiveRecord::Base.configurations['hrms_user_sync']['database_hrms_sync'], "server"=>ActiveRecord::Base.configurations['hrms_user_sync']['server_hrms_sync'], "host"=>ActiveRecord::Base.configurations['hrms_user_sync']['host_hrms_sync'], "port"=>ActiveRecord::Base.configurations['hrms_user_sync']['port_hrms_sync'], "username"=>ActiveRecord::Base.configurations['hrms_user_sync']['username_hrms_sync'], "password"=>ActiveRecord::Base.configurations['hrms_user_sync']['password_hrms_sync'], "encoding"=>ActiveRecord::Base.configurations['hrms_user_sync']['encoding_hrms_sync']}


    rec = AppSyncInfo.find_or_initialize_by_name('inia')
    rec.in_progress = true if options[:time]!=true
    rec.save
    @sync_time = rec.last_sync.localtime - 1.hour #Time.zone.parse(rec.last_sync.to_s).utc - 8.hour
    @last_sync_time = Time.now

    rec1 = AppSyncInfo.find_or_initialize_by_name('hrms')
    rec1.in_progress = true if options[:time]!=true
    if !rec1.last_sync.present?
      rec1.last_sync=Time.now
      @sync_time1 = (Time.now - 10.minute)
    else
      @sync_time1 = rec1.last_sync.localtime - 10.minute # Time.zone.parse(rec1.last_sync.to_s).utc - 8.hour#(rec1.last_sync-1.minute)
    end
    rec1.save


  if options[:type]=='inia'
    @sync_time = options[:range].present? ? options[:range]: ''
  elsif options[:type]=='hrms'
    @sync_time1 = options[:range].present? ? options[:range]: ''
  end
    users_info = @@user_info.present? rescue nil
    inia_time = @@inia_from.present? rescue nil
    hrms_time = @@hrms_from.present? rescue nil
    @sync_time = inia_time.present? ? inia_time : @sync_time
    @sync_time1 = hrms_time.present? ? hrms_time : @sync_time1


    p @sync_time
    @member_role_update = @@member_role rescue  nil
    @member_update =  @@member rescue nil

    Project.establish_connection(sync_details)

    Rails.logger.info "---HRMS @ #{@sync_time1} and iNia @ #{@sync_time}"
    Rails.logger.info "-- Project --"
    project_count = Project.count
    @projects = Project.find_by_sql("SELECT id, name, description, homepage, is_public, parent_id, identifier,status,lft,rgt, inherit_members, lastmodified FROM projects WHERE lastmodified >= '#{@sync_time}'")
    @inia_projects = Project.find_by_sql("SELECT id, name, description, homepage, is_public, parent_id, identifier, status, lft,rgt, inherit_members, lastmodified FROM projects")
    Rails.logger.info " Total projects in iNia : #{project_count}"
    Rails.logger.info " Sync projects from iNia : #{@projects.count}"
    Project.establish_connection(sync_details_development)
    s_ids = Project.find_by_sql("select id from projects")
    n_p_count = IniaProject.count
    Rails.logger.info " Total Inia-projects in Nanba before Sync : #{n_p_count}"
    @projects.each do |project|
      sql_values=""
      saved_project_values = project.attributes.values
      sql_values = sql_values + "(#{ saved_project_values.map{ |i| '"%s"' % i }.join(', ') }),"
      sql_values=sql_values.chomp(',')
      sql_query= "VALUES#{sql_values}"
      final_sql = "INSERT INTO inia_projects (id, name, description, homepage, is_public, parent_id, identifier, status,lft, rgt, inherit_members, lastmodified) #{sql_query} ON DUPLICATE KEY UPDATE id=VALUES(id), name=VALUES(name), description=VALUES(description), homepage=VALUES(homepage), is_public=VALUES(is_public), parent_id=VALUES(parent_id), identifier=VALUES(identifier), status=VALUES(status), lft=VALUES(lft), rgt=VALUES(rgt), inherit_members=VALUES(inherit_members),  lastmodified=VALUES(lastmodified)"
      connection = ActiveRecord::Base.connection
      connection.execute(final_sql.to_s)
      Rails.logger.info 'Project Sync done.'

      connection.close
    end
    # Rails.logger.info '---------- called project -------'

    # Delete Sync START
    desc_con1 = IniaProject.establish_connection(sync_details_development)
    source_members_ids1 = @inia_projects.map(&:id)
    dest_members1 = IniaProject.find_by_sql("SELECT id, name, description, homepage, is_public, parent_id, identifier, status, lft,rgt,inherit_members FROM inia_projects")
    dest_members_ids1 = dest_members1.map(&:id)
    delete_users1 = dest_members_ids1 - source_members_ids1
    if delete_users1.present?
      IniaProject.where(:id => delete_users1).destroy_all
    end
    n_p_count = IniaProject.count
    Rails.logger.info " Total Inia-projects in Nanba after Sync : #{n_p_count}"
    # Delete Sync END

    #================= user =============================
    Rails.logger.info "-- User -$$$$$$$$$$$$$$$$$-"
    hrms =  ActiveRecord::Base.establish_connection(hrms_sync_details).connection
    user_data = "SELECT first_name, last_name, login_id, work_email, employee_no, is_active, modified_date, prev_emp_no FROM vw_employee
where modified_date >= '#{@sync_time1}' and employee_no != 0 and work_email != '' and login_id !='' and is_active=1  "
    resigned_users = "SELECT first_name, last_name, login_id, work_email, employee_no, is_active, modified_date, prev_emp_no, dep_name,
                  loc_name, region_name, location_type FROM vw_employee where modified_date >= '#{@sync_time1}'
                  and employee_no != 0 and work_email != '' and login_id !='' and is_active=0"
    user_query = users_info.present? ? @@user_info : user_data
    @user_info = hrms.execute(user_query)
    @resigned_users =hrms.execute(resigned_users)
    hr_user_count = hrms.execute("select * from vw_employee")
    Rails.logger.info " Total users in HRMS : #{hr_user_count.count}"
    Rails.logger.info " Sync users from HRMS : #{@user_info.count}"
    hrms.disconnect!
    nanba =  ActiveRecord::Base.establish_connection(:production).connection
    nanba_users = nanba.execute("select * from users where type='User' and status=1")
    Rails.logger.info " Total users in nanba before Sync : #{nanba_users.count}"

    # Rails.logger.info "-------- 123 ----------------"
    @resigned_users.each(:as => :hash) do |user|
      p '=================resigned user============'
      p user['login_id']
      p '=========e nd=============='
      update_sql = "update users set login='#{user['login_id']}',firstname='#{user['first_name']}',lastname='#{user['last_name']}',mail='#{user['work_email']}',language='en', auth_source_id=1, status='#{user['is_active']==1 ? 1 : 3}',type='User', salt=NULL ,lastmodified=NOW() where id=(select user_id from user_official_infos where employee_id=#{user['employee_no']} limit 1)"
      nanba.execute(update_sql)
    end

    @user_info.each(:as => :hash) do |user|
      final_sql = "INSERT into users(login, firstname, lastname, mail, language, auth_source_id, created_on, hashed_password, status, last_login_on, type, identity_url, mail_notification, salt,  must_change_passwd, passwd_changed_on, lastmodified) VALUES ('#{user['login_id']}', '#{user['first_name']}','#{user['last_name']}','#{user['work_email']}','en',1, NOW(),'','#{user['is_active']==1 ? 1 : 3}',NULL,'User', NULL,'only_my_events',NULL,false,NULL,NOW())"

      emp_code_con = "select * from user_official_infos where employee_id=#{user['employee_no']}"

      last_emp_code = "INSERT into user_official_infos (user_id, employee_id) values ((select id from users where login='#{user['login_id']}' limit 1) ,#{user['employee_no']})ON DUPLICATE KEY UPDATE employee_id=VALUES(employee_id),user_id=VALUES(user_id)"

      update_sql = "update users set login='#{user['login_id']}',firstname='#{user['first_name']}',lastname='#{user['last_name']}',mail='#{user['work_email']}',language='en', auth_source_id=1, status='#{user['is_active']==1 ? 1 : 3}',type='User', salt=NULL ,lastmodified=NOW() where id=(select user_id from user_official_infos where employee_id=#{user['employee_no']} limit 1)"

      res1 =  nanba.execute(emp_code_con)
      emp_up = "update user_official_infos set user_id=(select id from users where login='#{user['login_id']}' limit 1) where employee_id=#{user['employee_no']}"
      user_count =  nanba.execute("select id from users where login='#{user['login_id']}'")

      if res1.count==0 && user_count.count==0 && user['prev_emp_no'].nil?
        Rails.logger.info "--- insert  - #{user['login_id']} - users ---"
        nanba.execute(final_sql)
        user_id = User.find_by_login(user['login_id']).id rescue nil
        lemp_code = "INSERT into user_official_infos (user_id, employee_id) values (#{user_id} ,#{user['employee_no']})ON DUPLICATE KEY UPDATE employee_id=VALUES(employee_id),user_id=VALUES(user_id)"
        nanba.execute(lemp_code)
      elsif user['prev_emp_no'].nil?
        Rails.logger.info "--- update - #{user['login_id']} - users ---"
        nanba.execute(last_emp_code) if res1.count == 0 && user['is_active']==1
        nanba.execute(update_sql)
        user_id = User.find_by_login(user['login_id']).id rescue nil
        MemberRole.establish_connection(:production)
        User.establish_connection(:production)
        Role.establish_connection(:production)
        Member.establish_connection(:production)
        g_user = "select id from users where type='group' and id in (select entity_id from sync_entities where entity='groups' and ref_entity = 'users' and can_sync=1)"
        ids = User.find_by_sql(g_user).map(&:id)
        ids.each do |id|
          begin
            MemberRole.establish_connection(:production)
            User.establish_connection(:production)
            Role.establish_connection(:production)
            Member.establish_connection(:production)
            Member.where(:user_id => id).each do |member|
              next if !member.project.present? || user_id.nil?
              user_member = Member.find_by_project_id_and_user_id(member.project_id, user_id) || Member.find_or_initialize_by_project_id_and_user_id(member.project_id, user_id)
              member.member_roles.each do |member_role|
                user_member.member_roles << MemberRole.find_or_initialize_by_role_id_and_inherited_from_and_member_id(member_role.role.id, member_role.id, user_member.id)
              end
              user_member.save!
            end
          rescue Exception => e
            Rails.logger.info "Exception db connection :  #{e.message} "
            p "Database connection faild"
            p '------------------check-----------------'

            #raise "Database connection failed"
          end
          if user_id.present?
            group_user = "insert into groups_users(group_id, user_id)values(#{id}, #{user_id})ON DUPLICATE KEY UPDATE group_id=VALUES(group_id),user_id=VALUES(user_id)"
            nanba.execute(group_user)
          end
        end

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
          p uoi.errors
        end
      end

          # if res1.count == 0
          #   nanba.execute(last_emp_code)
          # # else
          # #   nanba.execute(emp_up)
          # end
      end
    nanba_users_count = nanba.execute("select * from users where type='User' and status=1")
    Rails.logger.info " Total users in nanba after Sync : #{nanba_users_count.count}"
     hrtime = @@hrtime rescue nil
    rec1.update_attributes(:last_sync=>Time.now,:in_progress => false) if options[:time]!=true
      #================= user =============================

      #=====================Member========================
    Rails.logger.info "-- Member --"
    # p @member_update.present?
    # Rails.logger.info '=============================================================================================================='
    Member.establish_connection(sync_details)
    s_ids = Member.find_by_sql("select id from members")
    member_sql = !@member_update.present? ? "SELECT id, user_id, project_id, mail_notification, lastmodified FROM members WHERE lastmodified >= '#{@sync_time}'" : @member_update
    @source_members = Member.find_by_sql(member_sql)
    @source_members1 = Member.find_by_sql("SELECT id, user_id, project_id, mail_notification, lastmodified FROM members")

    Rails.logger.info " Total Members in iNia : #{s_ids.count}"
    Rails.logger.info " sync Members from iNia : #{@source_members.count}"

    UserOfficialInfo.establish_connection(sync_details)
    member_arr = []
    if @source_members.count > 0
      Rails.logger.info '-------------------------------'
      Rails.logger.info "Sync member record from iNia"
    end
    @source_members.each do |x|
      Rails.logger.info '======='
      p x
       employees = UserOfficialInfo.find_by_sql("select employee_id from user_official_infos where user_id=#{x.user_id}")
      if employees.present?
        id = employees.first.employee_id
        member_arr << [x.id,x.project_id, id !=nil ? id : nil]
      end
      Rails.logger.info "project_id : #{x.project_id}, user_id : #{x.user_id}, employee_id : #{id}"
    end
    if @source_members.count > 0
      Rails.logger.info '-------------------------------'
    end
    IniaMember.establish_connection(sync_details_development)
    inia_mem_count = IniaMember.count
    Rails.logger.info " Total IniaMembers in Nanba before sync : #{inia_mem_count}"
    if member_arr.count > 0
      Rails.logger.info '-------------------------------'
      Rails.logger.info "Sync member record from Nanba"
    end
    member_arr.each_with_index do |member,i|
      if member[2] != nil
        emp = ActiveRecord::Base.connection.execute("select user_id from user_official_infos where employee_id=#{member[2]}")
        user_ids = []
        emp.each(:as => :hash) do |pr|
          user_ids << pr['user_id']
        end
        usr_id = user_ids.compact.first

        Rails.logger.info "project_id : #{member[1]}, user_id : #{usr_id}, employee_id : #{member[2]}"
        if usr_id.present?
          final_sql = "INSERT INTO inia_members(id, user_id,project_id) values (#{member[0]},#{usr_id}, #{member[1]})ON DUPLICATE KEY UPDATE id=VALUES(id),user_id=VALUES(user_id),project_id=VALUES(project_id)"
          con = "select * from inia_members where user_id=#{usr_id} and project_id=#{member[1]}"
          connection = ActiveRecord::Base.connection
          res = connection.execute(con)
          connection.execute(final_sql.to_s) if res.count == 0
          Rails.logger.info 'Member Sync done'
          connection.close
        end
      end
    end
    if member_arr.count > 0
      Rails.logger.info '-------------------------------'
    end
    # # Delete Sync START
    cnn = IniaMember.establish_connection(sync_details_development)
    source_members_ids = @source_members1.map(&:id)
    # d_ids1 = IniaMember.find_by_sql("select id from inia_members")
    dest_members = IniaMember.find_by_sql("SELECT id FROM inia_members where id not in (select inia_member_id from approval_roles_inia_members where approval_role_id in (select id from approval_roles where can_restrict=1 ))")
    dest_members_ids = dest_members.map(&:id)
    delete_users = dest_members_ids - source_members_ids
    if delete_users.present?
      IniaMember.where(:id => delete_users).destroy_all
    end
    inia_mem_count = IniaMember.count
    Rails.logger.info " Total IniaMembers in Nanba  sync : #{inia_mem_count}"

    #==============Role ==========================

    Rails.logger.info "-- Role --"
    r = Role.establish_connection(sync_details)
    s_ids = Role.find_by_sql("select id from roles")
    @source_roles = Role.find_by_sql("SELECT id, name, position, assignable, builtin, permissions, issues_visibility, lastmodified FROM roles WHERE lastmodified >= '#{@sync_time}'")
    @inia_roles = Role.find_by_sql("SELECT id, name, position, assignable, builtin, issues_visibility, lastmodified FROM roles")

    Rails.logger.info "Total roles in iNia : #{s_ids.count}"
Rails.logger.info '================= to be sync roles'
    p @sync_time
   # Rails.logger.info "SELECT id, name, position, assignable, builtin, permissions, issues_visibility, lastmodified FROM roles WHERE lastmodified >= '#{@sync_time}'"
  #  Rails.logger.info '=====================time ====='
    IniaRole.establish_connection(sync_details_development)
    @source_roles.each do |role|
      sql_values=""
      saved_role_values = role.attributes.values
      if role.id.present?
        last_role = IniaRole.find(role.id) rescue nil
        find_role = last_role if last_role != nil
      end
      sql_values = sql_values + "(#{ saved_role_values.map{ |i| '"%s"' % i  }.join(', ') }),"
      sql_values=sql_values.chomp(',')
      sql_query= "VALUES#{sql_values}"
      data =   IniaRole.find(saved_role_values[0]) rescue nil
      final_sql = "INSERT inia_roles (id, name, position, assignable, builtin, permissions, issues_visibility, lastmodified) #{sql_query} ON DUPLICATE KEY UPDATE lastmodified=VALUES(lastmodified)"
      connection = ActiveRecord::Base.connection
      connection.execute(final_sql.to_s)
      Rails.logger.info 'Role Sync done'
      connection.close
      if role.id.present? && find_role.present?
        inia_role = IniaRole.find(find_role.id)
        inia_role.update_attributes(:permissions=> find_role.permissions)
      end
      if data.present?
        inia_role = IniaRole.find(saved_role_values[0])
        inia_role.permissions= saved_role_values[5]
        inia_role.save
      end
    end


    # Delete Sync START
    desc_con1 = IniaRole.establish_connection(sync_details_development)
    nan_role_count = IniaRole.count
    source_members_ids1 = @inia_roles.map(&:id)
    dest_members1 = IniaRole.find_by_sql("SELECT id, name, position, assignable, builtin, issues_visibility, lastmodified FROM inia_roles")
    dest_members_ids1 = dest_members1.map(&:id)
    delete_users1 = dest_members_ids1 - source_members_ids1
    # Rails.logger.info ' del roles --'
    # p delete_users1
    if delete_users1.present?
      IniaRole.where(:id => delete_users1).destroy_all
    end
    Rails.logger.info " Total roles in nanba after Sync : #{nan_role_count}"
    # Delete Sync END

    #======================MemberRole ==========================

    Rails.logger.info "-- Member Role --"
    MemberRole.establish_connection(sync_details)
    mem_role = @member_role_update.present? ? @member_role_update : "SELECT id, member_id, role_id, inherited_from, lastmodified FROM member_roles WHERE lastmodified >= '#{@sync_time}'"
    @source_member_roles = MemberRole.find_by_sql(mem_role)
    @inia_member_roles = MemberRole.find_by_sql("SELECT id, member_id, role_id, inherited_from, lastmodified FROM member_roles")
    Rails.logger.info "Total Member Role from Inia #{MemberRole.count}"
    IniaMemberRole.establish_connection(sync_details_development)
    IniaMember.establish_connection(sync_details_development)
    Member.establish_connection(sync_details)
    Rails.logger.info "Total Member Role from Nanba befoe Sync #{IniaMemberRole.count}"
    @source_member_roles.each do |member_role|
      Rails.logger.info '=== came ==='
      # p Member.last
      # Rails.logger.info '=============== a ==========='
      # p member_role.
      # raise
      # Member.find(member_role)
      sql_values=""
      saved_member_role_values = member_role.attributes.values
      sql_values = sql_values + "(#{ saved_member_role_values.map{ |i| '"%s"' % i }.join(', ') }),"
      sql_values=sql_values.chomp(',')
      sql_query= "VALUES#{sql_values}"
      final_sql = "INSERT INTO inia_member_roles (id, member_id, role_id, inherited_from, lastmodified) #{sql_query} ON DUPLICATE KEY UPDATE id=VALUES(id), member_id=VALUES(member_id), role_id=VALUES(role_id), inherited_from=VALUES(inherited_from),lastmodified=VALUES(lastmodified)"
      connection = ActiveRecord::Base.connection
      connection.execute(final_sql.to_s)
      connection.close

    end
     # Delete Sync START
    desc_con1 = IniaMemberRole.establish_connection(sync_details_development)
    source_members_ids1 = @inia_member_roles.map(&:id)
    dest_members1 = IniaMemberRole.find_by_sql("SELECT id, member_id, role_id, inherited_from, lastmodified FROM inia_member_roles")
    dest_members_ids1 = dest_members1.map(&:id)
    delete_users1 = dest_members_ids1 - source_members_ids1
    # Rails.logger.info ' delete IniaMemberRole --'
    # p delete_users1
    # p delete_users1.present?
    if delete_users1.present?
      IniaMemberRole.where(:id => delete_users1).destroy_all
      IniaMemberNanbaRole.where(:id => delete_users1).destroy_all
    end


    if options[:time]!=true
      rec = AppSyncInfo.find_or_initialize_by_name('inia')
      rec.in_progress = false
      rec.last_sync = @last_sync_time
      rec.save
    end
    Rails.logger.info "Total Member Role from Nanba befoe Sync #{IniaMemberRole.count}"
    Rails.logger.info '======= end ======='
  end

  def self.alter_lasmodify_field
    sync_details={"adapter"=>ActiveRecord::Base.configurations['sync_prod']['sync_adapter'], "database"=>ActiveRecord::Base.configurations['sync_prod']['sync_database'], "server"=>ActiveRecord::Base.configurations['sync_prod']['sync_server'], "host"=>ActiveRecord::Base.configurations['sync_prod']['sync_host'], "port"=>ActiveRecord::Base.configurations['sync_prod']['sync_port'], "username"=>ActiveRecord::Base.configurations['sync_prod']['sync_username'], "password"=>ActiveRecord::Base.configurations['sync_prod']['sync_password'], "encoding"=>ActiveRecord::Base.configurations['sync_prod']['sync_encoding']}
    sync_details_development={"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "server"=>ActiveRecord::Base.configurations['development']['server'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}

    Project.establish_connection(sync_details)
    User.establish_connection(sync_details)
    Member.establish_connection(sync_details)
    MemberRole.establish_connection(sync_details)
    Role.establish_connection(sync_details)
    AuthSource.establish_connection(sync_details)
           
    Project.connection.execute("ALTER TABLE projects ADD lastmodified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP")
    User.connection.execute("ALTER TABLE users ADD lastmodified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP")
    Member.connection.execute("ALTER TABLE members ADD lastmodified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP")
    Role.connection.execute("ALTER TABLE roles ADD lastmodified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP")
    MemberRole.connection.execute("ALTER TABLE member_roles ADD lastmodified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP")
    AuthSource.connection.execute("ALTER TABLE auth_sources ADD lastmodified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP")

  end

  def self.alter_lasmodify_field_local_db

      sync_details_development={"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "server"=>ActiveRecord::Base.configurations['development']['server'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}

      IniaProject.establish_connection(sync_details_development)
      User.establish_connection(sync_details_development)
      IniaMember.establish_connection(sync_details_development)
      IniaMemberRole.establish_connection(sync_details_development)
      IniaRole.establish_connection(sync_details_development)
      AuthSource.establish_connection(sync_details_development)

      IniaProject.connection.execute("ALTER TABLE projects ADD lastmodified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ON UPDATE CURRENT_TIMESTAMP")
      User.connection.execute("ALTER TABLE users ADD lastmodified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ON UPDATE CURRENT_TIMESTAMP")
      IniaMember.connection.execute("ALTER TABLE inia_members ADD lastmodified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ON UPDATE CURRENT_TIMESTAMP")
      IniaRole.connection.execute("ALTER TABLE inia_roles ADD lastmodified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ON UPDATE CURRENT_TIMESTAMP")
      IniaMemberRole.connection.execute("ALTER TABLE inia_member_roles ADD lastmodified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ON UPDATE CURRENT_TIMESTAMP")
      AuthSource.connection.execute("ALTER TABLE auth_sources ADD lastmodified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ON UPDATE CURRENT_TIMESTAMP")

  end

  def self.pull_inia_infos(from,user_ids)

   @@inia_from = from.present? ? "lastmodified>='#{from}'" : "lastmodified>=''"
  p  @@member = "select * from members where user_id in (select user_id from user_official_infos where employee_id in (#{user_ids})) and "+ @@inia_from
  p  @@member_role = "select * from member_roles where member_id in (select id from members where user_id in (
select user_id from user_official_infos where employee_id in (#{user_ids}))) and " + @@inia_from
    Sync.sync_sql({:time =>false})
  end

  def self.pull_hrms_infos(from,user_ids)
   p  @@hrms_from = from.present? ? "modified_date>='#{from}'" : "modified_date>=''"
   Rails.logger.info '======================= hrms ============'
  p  @@user_info = "SELECT first_name, last_name, login_id, work_email, employee_no, is_active, modified_date, prev_emp_no FROM vw_employee where employee_no in ('#{user_ids}') and work_email != '' and login_id !='' and " + @@hrms_from
    Sync.sync_sql({:time =>false})
  end








end
