class Synch < ActiveRecord::Base
  def self.sync_sql
    sync_details={"adapter"=>ActiveRecord::Base.configurations['sync_prod']['adapter_sync'], "database"=>ActiveRecord::Base.configurations['sync_prod']['database_sync'], "server"=>ActiveRecord::Base.configurations['sync_prod']['server_sync'], "host"=>ActiveRecord::Base.configurations['sync_prod']['host_sync'], "port"=>ActiveRecord::Base.configurations['sync_prod']['port_sync'], "username"=>ActiveRecord::Base.configurations['sync_prod']['username_sync'], "password"=>ActiveRecord::Base.configurations['sync_prod']['password_sync'], "encoding"=>ActiveRecord::Base.configurations['sync_prod']['encoding_sync']}
    sync_details_development={"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "server"=>ActiveRecord::Base.configurations['development']['server'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}

    @sync_groups=["projects","users","members","member_roles","roles","auth_sources", "tokens"]
    @errors=[]
    @errors1=[]
    if @sync_groups.present?
      @sync_groups.each do |each_table|
        begin
          if each_table == "projects"
            p = Project.establish_connection(sync_details)
            @projects = Project.find_by_sql("SELECT id,name,description,homepage,is_public,parent_id,identifier,status,lft,rgt,inherit_members
FROM projects WHERE lastmodified >  (NOW() - INTERVAL 20 MINUTE)")
            @inia_projects = Project.find_by_sql("SELECT id,name,description,homepage,is_public,parent_id,identifier,status,lft,rgt,inherit_members
FROM projects")
            Project.establish_connection(sync_details_development)
            s_ids = Project.find_by_sql("select id from projects")
            @projects.each do |project|
              sql_values=""
              saved_project_values = project.attributes.values
              sql_values = sql_values + "(#{ saved_project_values.map{ |i| '"%s"' % i }.join(', ') }),"
              sql_values=sql_values.chomp(',')
              sql_query= "VALUES#{sql_values}"
              final_sql = "INSERT INTO inia_projects (id,name,description,homepage,is_public,parent_id,identifier,status,lft,rgt,inherit_members)
         #{sql_query} ON DUPLICATE KEY UPDATE id=VALUES(id),name=VALUES(name),description=VALUES(description),homepage=VALUES(homepage),is_public=VALUES(is_public),parent_id=VALUES(parent_id),identifier=VALUES(identifier),status=VALUES(status),lft=VALUES(lft),rgt=VALUES(rgt),inherit_members=VALUES(inherit_members)"
              connection = ActiveRecord::Base.connection
             # connection = ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['production'])
              connection.execute(final_sql.to_s)
              connection.close
            end
p '-------------- called project -------'

            # Delete Sync START          
            desc_con1 = IniaProject.establish_connection(sync_details_development)
            source_members_ids1 = @inia_projects.map(&:id)
            dest_members1 = IniaProject.find_by_sql("SELECT id,name,description,homepage,is_public,parent_id,identifier,status,lft,rgt,inherit_members
FROM inia_projects")
            dest_members_ids1 = dest_members1.map(&:id)
            delete_users1 = dest_members_ids1 - source_members_ids1 
            if delete_users1.present?
              IniaProject.where(:id => delete_users1).destroy_all
            end

            # Delete Sync END


          elsif each_table == "users"
            p "Synch Users..!"
            User.establish_connection(sync_details)
            @source_users = User.find_by_sql("SELECT id,login,hashed_password,firstname,lastname,mail,status,last_login_on,language,auth_source_id,type,identity_url,mail_notification,salt,must_change_passwd,passwd_changed_on
FROM users WHERE lastmodified >  (NOW() - INTERVAL 60 MINUTE)")
 @inia_users = User.find_by_sql("SELECT id,login,hashed_password,firstname,lastname,mail,status,last_login_on,language,auth_source_id,type,identity_url,mail_notification,salt,must_change_passwd,passwd_changed_on
FROM users")            
            s_ids2 = User.find_by_sql("select id from users")
           @sourece_con =  User.establish_connection(sync_details_development)
            @source_users.each do |user|
              sql_values=""
              saved_users_values = user.attributes.values
              sql_values = sql_values + "(#{ saved_users_values.map{ |i| '"%s"' % i }.join(', ') }),"
              sql_values=sql_values.chomp(',')
              sql_query= "VALUES#{sql_values}"
              final_sql = "INSERT users
(id,login,hashed_password,firstname,lastname,mail,status,last_login_on,language,auth_source_id,type,identity_url,mail_notification,salt,must_change_passwd,passwd_changed_on)
 #{sql_query}
ON DUPLICATE KEY UPDATE id=VALUES(id),login=VALUES(login),hashed_password=VALUES(hashed_password),firstname=VALUES(firstname),lastname=VALUES(lastname),mail=VALUES(mail),status=VALUES(status),last_login_on=VALUES(last_login_on),language=VALUES(language),auth_source_id=VALUES(auth_source_id),type=VALUES(type),identity_url=VALUES(identity_url),mail_notification=VALUES(mail_notification),salt=VALUES(salt),must_change_passwd=VALUES(must_change_passwd),passwd_changed_on=VALUES(passwd_changed_on)";
              connection = ActiveRecord::Base.connection
              connection.execute(final_sql.to_s)
              connection.close
              if user.id.present?
                find_user = User.find(user.id)
                find_user.auth_source_id= user.auth_source_id.present? ? user.auth_source_id : nil
                # find_user.admin = user.admin==true ? true : false
                find_user.save
              else
                sql_for_inserted_id="SELECT LAST_INSERT_ID() from users LIMIT 1"
                find_inserted_record =connection.execute(sql_for_inserted_id)
                if find_inserted_record.present? && find_inserted_record.first[0] != 0
                  user = User.find(find_inserted_record.first[0])
                  user.update_attributes(:auth_source_id=> find_user.auth_source_id.present? ? find_user.auth_source_id : nil,:admin=>find_user.admin==true ? true : false)  
                end
              end
            end

            # Delete Sync START          
            desc_con1 = User.establish_connection(sync_details_development)
            source_members_ids1 = @inia_users.map(&:id)
            dest_members1 = User.find_by_sql("SELECT id,login,hashed_password,firstname,lastname,mail,status,last_login_on,language,auth_source_id,type,identity_url,mail_notification,salt,must_change_passwd,passwd_changed_on
FROM users")
            dest_members_ids1 = dest_members1.map(&:id)
            delete_users1 = dest_members_ids1 - source_members_ids1 
            p '---- del user --'
            p delete_users1
            if delete_users1.present?
              User.where(:id => delete_users1).destroy_all
            end

            # Delete Sync END

            
          elsif each_table == "members"
            Rails.logger.info "Synch Members..!"
            Member.establish_connection(sync_details)
            s_ids = Member.find_by_sql("select id from members")
            @source_members = Member.find_by_sql("SELECT id,user_id,project_id,mail_notification
FROM members WHERE lastmodified >  (NOW() - INTERVAL 20 MINUTE)")
@source_members1 = Member.find_by_sql("SELECT id,user_id,project_id,mail_notification
FROM members")
            Member.establish_connection(sync_details_development)
            @source_members.each do |member|
              sql_values=""
              saved_members_values = member.attributes.values
              sql_values = sql_values + "(#{ saved_members_values.map{ |i| '"%s"' % i }.join(', ') }),"
              sql_values=sql_values.chomp(',')
              sql_query= "VALUES#{sql_values}"
              final_sql = "INSERT INTO inia_members
(id,user_id,project_id,mail_notification)
 #{sql_query}
ON DUPLICATE KEY UPDATE id=VALUES(id),user_id=VALUES(user_id),mail_notification=VALUES(mail_notification)"
              connection = ActiveRecord::Base.connection
              connection.execute(final_sql.to_s)
              connection.close
            end
            # # Delete Sync START

            IniaMember.establish_connection(sync_details_development)
            source_members_ids = @source_members1.map(&:id)
            # d_ids1 = IniaMember.find_by_sql("select id from inia_members")
            dest_members = IniaMember.find_by_sql("SELECT id,user_id,project_id,mail_notification
FROM inia_members")
            dest_members_ids = dest_members.map(&:id)
            delete_users = dest_members_ids - source_members_ids 
            p dest_members_ids.count
            p source_members_ids.count
            p '------def IniaMember--------'
            p delete_users
            p '---'
            if delete_users.present?
              IniaMember.where(:id => delete_users).destroy_all
            end
            # # Delete Sync END


         elsif each_table == "roles"

           Rails.logger.info "Synch Roles..!"
           r = Role.establish_connection(sync_details)
           s_ids = Role.find_by_sql("select id from roles")
           @source_roles = Role.find_by_sql("SELECT id,name,position,assignable,builtin,issues_visibility
FROM roles WHERE lastmodified >  (NOW() - INTERVAL 20 MINUTE)")
           @inia_roles = Role.find_by_sql("SELECT id,name,position,assignable,builtin,issues_visibility
FROM roles")
           Role.establish_connection(sync_details_development)

           @source_roles.each do |role|
             sql_values=""
             saved_role_values = role.attributes.values
             if role.id.present?
               find_role = Role.find(role.id)
             end
             sql_values = sql_values + "(#{ saved_role_values.map{ |i| '"%s"' % i  }.join(', ') }),"
             sql_values=sql_values.chomp(',')
             sql_query= "VALUES#{sql_values}"
             final_sql = "INSERT inia_roles
(id,name,position,assignable,builtin,issues_visibility)
  #{sql_query}
ON DUPLICATE KEY UPDATE id=VALUES(id),name=VALUES(name),position=VALUES(position),assignable=VALUES(assignable),builtin=VALUES(builtin),issues_visibility=VALUES(issues_visibility)"

             connection = ActiveRecord::Base.connection
             connection.execute(final_sql.to_s)
             connection.close
             if role.id.present?
               inia_role = IniaRole.find(find_role.id)
               inia_role.update_attributes(:permissions=> find_role.permissions)

             else
               sql_for_inserted_id="SELECT LAST_INSERT_ID() from roles LIMIT 1"
               find_inserted_record =connection.execute(sql_for_inserted_id)
               if find_inserted_record.present? && find_inserted_record.first[0] != 0
                 role = IniaRole.find(find_inserted_record.first[0])
                 role.update_attributes(:permissions=> find_role.permissions)
               end
             end
           end


            # Delete Sync START          
            desc_con1 = IniaRole.establish_connection(sync_details_development)
            source_members_ids1 = @inia_roles.map(&:id)
            dest_members1 = IniaRole.find_by_sql("SELECT id,name,position,assignable,builtin,issues_visibility
FROM inia_roles")
            dest_members_ids1 = dest_members1.map(&:id)
            delete_users1 = dest_members_ids1 - source_members_ids1 
            p '---- del roles --'
            p delete_users1
            if delete_users1.present?
              IniaRole.where(:id => delete_users1).destroy_all
            end

            # Delete Sync END

          elsif each_table == "member_roles"
            Rails.logger.info "Synch Member_roles..!"
            mr = MemberRole.establish_connection(sync_details)
            @source_member_roles = MemberRole.find_by_sql("SELECT id,member_id,role_id,inherited_from
FROM member_roles WHERE lastmodified >  (NOW() - INTERVAL 20 MINUTE)")

            @inia_member_roles = MemberRole.find_by_sql("SELECT id,member_id,role_id,inherited_from
FROM member_roles")
            MemberRole.establish_connection(sync_details_development)
            @source_member_roles.each do |member_role|
              sql_values=""
              saved_member_role_values = member_role.attributes.values
              sql_values = sql_values + "(#{ saved_member_role_values.map{ |i| '"%s"' % i }.join(', ') }),"
              sql_values=sql_values.chomp(',')
              sql_query= "VALUES#{sql_values}"
              final_sql = "INSERT INTO inia_member_roles
(id,member_id,role_id,inherited_from)
#{sql_query}
ON DUPLICATE KEY UPDATE id=VALUES(id),member_id=VALUES(member_id),role_id=VALUES(role_id),inherited_from=VALUES(inherited_from)"
              connection = ActiveRecord::Base.connection
              connection.execute(final_sql.to_s)
              connection.close
            end
          mr.close
             # Delete Sync START          
            desc_con1 = IniaMemberRole.establish_connection(sync_details_development)
            source_members_ids1 = @inia_member_roles.map(&:id)
            dest_members1 = IniaMemberRole.find_by_sql("SELECT id,member_id,role_id,inherited_from
FROM inia_member_roles")
            dest_members_ids1 = dest_members1.map(&:id)
            delete_users1 = dest_members_ids1 - source_members_ids1 
            p '---- del IniaMemberRole --'
            p delete_users1
            if delete_users1.present?
              IniaMemberRole.where(:id => delete_users1).destroy_all
            end


          elsif each_table == "auth_sources"
            Rails.logger.info "Synch Auth Sources..!"
           AuthSource.establish_connection(sync_details)
            s_ids = AuthSource.find_by_sql("select id from auth_sources")
            @source_auth_sources = AuthSource.find_by_sql("SELECT id,type,name,host,port,account,account_password,base_dn,attr_login,attr_firstname,attr_lastname,attr_mail,onthefly_register,tls,filter,timeout
FROM auth_sources WHERE lastmodified >  (NOW() - INTERVAL 20 MINUTE)")
            @inia_sources = AuthSource.find_by_sql("SELECT id,type,name,host,port,account,account_password,base_dn,attr_login,attr_firstname,attr_lastname,attr_mail,onthefly_register,tls,filter,timeout
FROM auth_sources")
            AuthSource.establish_connection(sync_details_development)
            @source_auth_sources.each do |auth_source|
              sql_values=""
              saved_auth_source_values = auth_source.attributes.values
              sql_values = sql_values + "(#{ saved_auth_source_values.map{ |i| '"%s"' % i }.join(', ') }),"
              sql_values=sql_values.chomp(',')
              sql_query= "VALUES#{sql_values}"
              final_sql = "INSERT INTO auth_sources
(id,type,name,host,port,account,account_password,base_dn,attr_login,attr_firstname,attr_lastname,attr_mail,onthefly_register,tls,filter,timeout)
 #{sql_query}
ON DUPLICATE KEY UPDATE id=VALUES(id),type=VALUES(type),name=VALUES(name),
host=VALUES(host),port=VALUES(port),account=VALUES(account),account_password=VALUES(account_password)
,base_dn=VALUES(base_dn),attr_login=VALUES(attr_login),attr_firstname=VALUES(attr_firstname),attr_lastname=VALUES(attr_lastname),
attr_mail=VALUES(attr_mail),onthefly_register=VALUES(onthefly_register),tls=VALUES(tls),filter=VALUES(filter),timeout=VALUES(timeout)"
              connection = ActiveRecord::Base.connection
              connection.execute(final_sql.to_s)
              connection.close
            end

            # Delete Sync START          
            desc_con1 = AuthSource.establish_connection(sync_details_development)
            source_members_ids1 = @inia_sources.map(&:id)
            dest_members1 = AuthSource.find_by_sql("SELECT id,type,name,host,port,account,account_password,base_dn,attr_login,attr_firstname,attr_lastname,attr_mail,onthefly_register,tls,filter,timeout
FROM auth_sources")
            dest_members_ids1 = dest_members1.map(&:id)
            delete_users1 = dest_members_ids1 - source_members_ids1 
            p '---- del auth_sources --'
            p delete_users1
            if delete_users1.present?
              AuthSource.where(:id => delete_users1).destroy_all
            end

            # Delete Sync END
          end
        rescue Exception => e
          @errors<< each_table
          @errors1<< {each_table=> e}
          next
        end
      end
    end
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

    #sync_details={"adapter"=>ActiveRecord::Base.configurations['sync_prod']['sync_adapter'], "database"=>ActiveRecord::Base.configurations['sync_prod']['sync_database'], "server"=>ActiveRecord::Base.configurations['sync_prod']['sync_server'], "host"=>ActiveRecord::Base.configurations['sync_prod']['sync_host'], "port"=>ActiveRecord::Base.configurations['sync_prod']['sync_port'], "username"=>ActiveRecord::Base.configurations['sync_prod']['sync_username'], "password"=>ActiveRecord::Base.configurations['sync_prod']['sync_password'], "encoding"=>ActiveRecord::Base.configurations['sync_prod']['sync_encoding']}
    sync_details_development={"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "server"=>ActiveRecord::Base.configurations['development']['server'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}

    Project.establish_connection(sync_details_development)
    User.establish_connection(sync_details_development)
    IniaMember.establish_connection(sync_details_development)
    IniaMemberRole.establish_connection(sync_details_development)
    IniaRole.establish_connection(sync_details_development)
    AuthSource.establish_connection(sync_details_development)
    
    Project.connection.execute("ALTER TABLE projects ADD lastmodified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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



end
