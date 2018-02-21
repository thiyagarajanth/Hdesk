module TicketingApprovalSystem
  module Infectors
    module Mailer
      module ClassMethods ;end
      module InstanceMethods;  end
      def self.included(receiver)
        def request_remainder_mail(mail)
          issue = mail.issue
          redmine_headers 'Project' => issue.project.identifier
           # @author = issue.author
           @author = User.find(mail.user_id)
           @subject = issue.subject
           @description = issue.description
           @date = issue.due_date.strftime("%d-%b-%Y")
           @dept_name = issue.project.name
           cc_id = ApprovalRole.set_assignee_value(issue)
          p 'mail--------------------1-----'
           begin 
            cc_users = User.find(cc_id).mail
            p 'mail-----------------------2--'
           rescue
             p cc_id
             cc_users =User.find_by_sql("SELECT mail FROM users INNER JOIN groups_users ON users.id = groups_users.user_id WHERE users.type IN ('User', 'AnonymousUser') AND groups_users.group_id =#{cc_id}").map(&:mail)
            #cc_users = Group.find(cc_id).users.map(&:mail)
            p 'mail-----------------------3--'
           end
           @comment = "Your request validity will be expire on #{issue.due_date}, If you want to renewal please create a ticket in NANBA."
           @news_url = url_for(:controller => 'issues', :action => 'show', :id => issue.id)
          mail(:to => @author.mail,:cc => cc_users, :subject => "Notification from #{issue.project.name} ")
        end

        def admin_remainder(mail)
          issue = mail.issue
          redmine_headers 'Project' => issue.project.identifier
           @author = User.find(mail.user_id)
           @news_url = url_for(:controller => 'issues', :action => 'show', :id => issue.id)
            @subject = issue.subject
            @description = issue.description
            @date = issue.due_date.strftime("%d-%b-%Y")
           cc_id = ApprovalRole.set_assignee_value(issue)
           begin 
            cc_users = User.find(cc_id).mail
           rescue
            cc_users = User.find_by_sql("Select mail from users where id in (select user_id from groups_users where group_id=#{cc_id})").map(&:mail)
           end
          mail(:to => cc_users ,:cc => @author.mail,:subject => "ALERT ! - REVOKE ACCESS FOR EXPIRED PRIVILEGES.",:importance => "High",'X-Priority' => '1')
        end

        def delegation_remainder(primary, secondary, count, ar)
          users = Principal.find([primary, secondary])
          @tickets_url = url_for(:controller => 'issues', :action => 'index',  "set_filter"=>"1", "f"=>["status_id", ""], "op"=>{"status_id"=>"="}, "v"=>{"status_id"=>["37"]}, "c"=>["subject", "author", "assigned_to", "priority", "status", "created_on", "updated_on"], "group_by"=>"", "project_id"=>"itops")
          @primary = users.first
          @secondary = users.last
          @user = User.current.present? ? Principal.find(User.current.id).name : 'Nanba Admin'
          @count = count
          @from_date = ar.active_from.strftime("%d-%b-%Y") rescue nil
          @to_date = ar.active_till.strftime("%d-%b-%Y") rescue nil
          mail(:to => @primary.mail,:cc => @secondary.mail, :subject => "Nanba Delegation Notification ")
        end

      end
    end
  end
end