module TicketingApprovalSystem
  module Infectors
    module Issue
      module ClassMethods; end
      module InstanceMethods
        def request_category
          @request_category = self.project_category.cat_name rescue nil
        end
        def request_status
          if self.due_date.nil?
            @request_status   = nil
          elsif self.due_date >= Date.today
            @request_status  = 'Active' 
          elsif self.due_date < Date.today
            @request_status   = 'Expired'          
          end
        end
        def pending_time
          sla_time_helper = Object.new.extend(SlaTimeHelper) 
          sla_time_helper.sla_time_count(self) rescue 0
        end
        def request_project
          self.inia_project.present? ? self.inia_project.name : ""
        end
      end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          has_one :ticket_tag, :through => :issue_ticket_tag
          has_one :inia_project, :through => :issue_ticket_tag
          has_one :project_category, :through => :issue_ticket_tag
          has_one :issue_ticket_tag
          has_one :request_remainder
          has_many :issue_approval_details
          has_many :ticket_approval_flows
          has_one :user_rating
          serialize :access_users
          
          before_save :update_previous_status
          before_save :check_resolved_tickets
          after_create :create_sla_time_start

          def create_sla_time_start
            SlaTime.create(:issue_id => self.id, :issue_sla_status_id => self.status_id,:user_id => self.assigned_to_id,  :old_status_id => nil , :pre_status_duration => 0 )
          end

          after_create :create_sla_time_start

          def create_sla_time_start
            SlaTime.create(:issue_id => self.id, :issue_sla_status_id => self.status_id,:user_id => self.assigned_to_id,  :old_status_id => nil , :pre_status_duration => 0 )
          end

          after_save :reassign_ticket


          def assign_params_from_controller(tag)
            @tag = tag
          end

          def reassign_ticket
            if self.status.name == 'Resolved' && self.assigned_to_id != self.author_id
              unless self.project.enabled_modules.map(&:name).include?('status_assignee')
                self.assigned_to_id = self.author_id
                self.save
              end
              push_external_tag_tickets('Resolved')
            end

            if self.status.name == 'Closed' && self.ticket_tag.present? && self.ticket_tag.have_agreement?
              key = Redmine::Configuration['iServ_api_key']
              base_url = Redmine::Configuration['iServ_url']
              url = base_url+"/services/message/sync"
              emp_id = UserOfficialInfo.find_by_user_id(self.author_id).employee_id
              code = self.ticket_tag.present? ?  self.ticket_tag.agreement_code : ''
              date = self.due_date.present? ? self.due_date.strftime("%Y-%m-%d") : ''
              params = {:serviceId => "updateEmployeeAgreementInfo",
                :input => {:employeeId=>emp_id,:agreementCode=>code,:ticketId=>self.id,:validTillDate=>date}.to_json
              }.to_json
              begin
               p code_name = RestClient::Request.execute(:method => :post,:url => url,
                :payload =>params ,:headers => {'Accept' => :json, 'Content-Type' => 'application/json','Auth-key' => key },:verify_ssl => false)
              rescue RestClient::Exception => e
                puts e.http_body
              end
            end
          end

          def send_notification_to_auto_tickets
            if self.status.name == 'Resolved' || self.status.name == 'Rejected'
              key = Redmine::Configuration['iServ_api_key']
              base_url = Redmine::Configuration['iServ_url']
              require 'json'
              require 'rest_client'
              url = base_url+"/services/notifications/ticket/"+self.id.to_s
              begin
                request = {:id => self.id,:status => self.status.name, :updatedOn => self.updated_on}.to_json
                RestClient::Request.new(:method => :post, :url => url, :payload => request, :headers => {:content_type => 'json',"Auth-key" => key}, :verify_ssl => false).execute.body
              rescue => e
                Rails.logger.info '===== Exception error'
                Rails.logger.info e.message
              end
            end
          end

          def check_resolved_tickets
            if @tag && @tag.validity > 0
              if self.due_date.nil?
                errors.add('Please select', " Access Required Till")
                return false
              end
            end
          end

          # Returns an array of statuses that user is able to apply
          def new_statuses_allowed_to(user=User.current, include_default=false)
            if new_record? && @copied_from
              [IssueStatus.default, @copied_from.status].compact.uniq.sort
            else
              initial_status = nil
              if new_record?
                initial_status = IssueStatus.default
              elsif status_id_was
                initial_status = IssueStatus.find_by_id(status_id_was)
              end
              initial_status ||= status

              initial_assigned_to_id = assigned_to_id_changed? ? assigned_to_id_was : assigned_to_id
              assignee_transitions_allowed = initial_assigned_to_id.present? &&
                  (user.id == initial_assigned_to_id || user.group_ids.include?(initial_assigned_to_id))

              statuses = initial_status.find_new_statuses_allowed_to(
                  user.admin ? Role.all : user.roles_for_project(project),
                  tracker,
                  author == user,
                  assignee_transitions_allowed
              )

              statuses << initial_status unless statuses.empty?
              statuses << IssueStatus.default if include_default
              statuses = statuses.compact.uniq.sort
              statuses = (User.current.admin? || self.author == user) ? statuses : statuses.reject {|s| s.name == 'Closed' }
              blocked? ? statuses.reject {|s| s.is_closed?} : statuses

            end
          end

          def update_previous_status
            self.pre_status_id = self.status_id_was
            tag = self.issue_ticket_tag
            if self.status.name == 'Resolved'
              if tag.present? && tag.ticket_tag.present?
                tag = tag.ticket_tag
                validity = tag.validity.present? ? tag.validity : 0
                if validity > 0 && self.due_date.present?
                if self.access_users.present?
                  self.access_users.each do |each_user|
                  request = RequestRemainder.find_or_initialize_by_issue_id_and_user_id(self.id, each_user.to_i)
                  request.validity = self.due_date
                  request.ticket_tag_id = tag.id
                  request.project_id = self.project_id
                  request.save
                  end
                else
                  request = RequestRemainder.find_or_initialize_by_issue_id_and_user_id(self.id, self.author_id)
                  request.validity = self.due_date
                  request.ticket_tag_id = tag.id
                  request.project_id = self.project_id
                  request.save
                end

                end
              end
              if self.time_entries.count==0
                entry = TimeEntry.new(:issue_id =>self.id, :project_id => self.project_id)
                entry.user_id=User.current.id
                entry.activity_id = TimeEntryActivity.shared.active.first.id
                entry.hours = 0
                entry.spent_on=Date.today
                entry.save
                p entry.errors
              end
            end
            name = IssueStatus.find(self.pre_status_id).name if self.pre_status_id.present?
            if name === 'Rejected' && self.status.name == 'Rejected'
                self.assigned_to_id = self.author.id
              # self.ticketing_approval.update_attributes(status: '')
            end
            if name === 'Resolved'  && self.status.name == 'Reopen'
              # if tag.present? && tag.ticket_tag.present?
              default_assignee =  DefaultAssigneeSetup.find_or_initialize_by_project_id_and_tracker_id(:project_id=> self.project_id ,:tracker_id=>self.tracker_id)
              self.assigned_to_id = default_assignee.default_assignee_to
              if tag.present? && tag.ticket_tag.present? && tag.ticket_tag.ticket_approvals.first.present?
                def_id = tag.ticket_tag.ticket_approvals.first.id
              else
                def_id =  nil
              end
                TicketApprovalFlow.create(:issue_id => self.id, :ticket_approval_id => def_id, :user_id => self.assigned_to_id, :status => 'pending', :notes => 'reopen' )
            end
          end


          def notified_users
            notified = []
            # Author and assignee are always notified unless they have been
            # locked or don't want to be notified
            notified << author if author
            if assigned_to
              notified += (assigned_to.is_a?(Group) ? assigned_to.users : [assigned_to])
            end
            if assigned_to_was
              notified += (assigned_to_was.is_a?(Group) ? assigned_to_was.users : [assigned_to_was])
            end
            notified = notified.select {|u| u.active? && u.notify_about?(self)}

            #notified += project.notified_users
            notified.uniq!
            # Remove users that can not view the issue
            notified.reject! {|user| !visible?(user)}
            notified
          end

          def ticket_need_approval(infos, params)
            current_user_id = params[:user_id].present? ? params[:user_id] : User.current.id
            comments = params[:comment].present? ? params[:comment] : '.'
            user_level = current_user_role(self)
            waiting_status = IssueStatus.find_by_name('Waiting for approval')
            approvals = infos.where("user_id IS NULL")
            interrupts = infos.where("user_id IS NOT NULL").order('ref_id')
            supr_user = user_level >= approvals.last.approval_role.level
            self.init_journal(User.find(current_user_id), comments)
            if approvals.present? && user_level < approvals.last.approval_role.level || (interrupts.present? && supr_user && interrupts.map(&:user_id).compact.present?)
              assign_user, assign_level = get_next_approver(user_level+1)
              role_id = ApprovalRole.find_by_level_and_project_id(assign_level,self.ticket_tag.project_id)
              approval_id = self.ticket_tag.ticket_approvals.find_by_approval_role_id(role_id)
              info = ApprovalRole.find_by_level(user_level+1).ticket_approvals.find_by_ticket_tag_id(self.ticket_tag.id) if !supr_user
              if supr_user || (interrupts.present? && user_level+1 >= interrupts.first.parent.approval_role.level)
                inter =  interrupts.first
                self.assigned_to_id = inter.user_id
                def_id = inter.id
              elsif info.present? && info.child.present?
                self.assigned_to_id = info.child.user_id
                def_id = info.child.id
              else
                self.assigned_to_id = assign_user
                def_id = approval_id.id
              end
              TicketApprovalFlow.create(:issue_id => self.id, :ticket_approval_id => def_id, :user_id => self.assigned_to_id, :status => 'pending', :notes => '' )
              self.status_id = waiting_status.id
              self.pre_status_id = waiting_status.id
            else
              self.assigned_to_id = ApprovalRole.set_assignee_value(self)
              # journal =  Journal.create(journalized_id: self.id, journalized_type: 'Issue', user_id: User.current.id,notes: "Approved" )
              status = IssueStatus.find_by_name('open')
              old_status = IssueStatus.find_by_name('waiting for approval')
              # JournalDetail.create(journal_id: journal.id, property: "attr", prop_key: "status_id", old_value: old_status.id, value: status.id)
              if self.project.enabled_modules.map(&:name).include?('redmine_issue_sla')
                SlaTime.create(:issue_id => self.id, :issue_sla_status_id => status.id,:user_id => self.assigned_to_id,  :old_status_id => old_status.id , :pre_status_duration => 0 )
              end
              self.status_id = status.id
              self.pre_status_id = self.status_id_was
              if self.ticket_tag.present? && self.ticket_tag.have_agreement == true
                status = IssueStatus.find_or_initialize_by_name('Accept Agreement')
                status.save
                self.status_id = status.id
                self.assigned_to_id = self.author_id
              end
            end
             if self.assigned_to_id.present?
               saved = self.save
               if self.status.name == 'Accept Agreement'
                Journal.create(journalized_id: self.id, journalized_type: 'Issue', user_id: User.current.id,notes: "Please accept the Agreement for further action." )
               end
               if saved
                 helper = Object.new.extend(CategoryApprovalConfigsHelper)
                 helper.push_notification(self)
                 true
               end
             end
          end

          def get_next_approver(next_level,*args)
            result = []
            project = args.present? ? args.last : self.inia_project
            roles = project.approval_role_users.where(:project_id => self.project_id)
            req_ap = self.ticket_tag.ticket_approvals.count
            auth_level = get_author_role(project, self)
            next_level = auth_level >= next_level ? auth_level + 1 : next_level
            roles.each do |role|
              if role.approval_role.present? && role.approval_role.level == next_level &&  role.approval_role.level <= req_ap
                result << [(role.user_id rescue nil), next_level]
              end
            end
            result.count == 0 ? [nil] : result.first
          end

          def get_author_role(project, issue)
            # roles = project.approval_role_users.where(:user_id => user.id, :project_id => project.id)
            level = []
            roles = project.approval_role_users.where( :project_id => issue.project_id)
            if roles.present?
              roles.collect{|rec| level << rec.approval_role.level  if rec.approval_role.present? && (rec.user_id rescue nil) == issue.author_id }.compact
              lel = level.max
              lel.present? ? lel : 0
            else
              0
            end
          end

          def current_user_role(issue,*args)
            project = args.present? ? args.last : self.inia_project
            begin
            # roles = project.approval_role_users.where(:user_id => User.current.id, :project_id => self.project_id)
              roles = project.approval_role_users.where( :project_id => self.project_id)
            rescue
              roles = nil
            end
            if roles.present?
              level = roles.collect{|rec| rec.approval_role.level if rec.approval_role.present? && (rec.user_id rescue nil)== User.current.id }.compact
              lel = level.max
              lel.present? ? lel : 0
            else
              0
            end
          end

          def get_first_approval(project, tag)
            cur_level = current_user_role(self, project)
            app_levels = project.approval_role_users.where(:project_id => tag.project_id)
            max_level = tag.ticket_approvals.where("user_id IS NULL").count
            req_lvl = app_levels.map{|rec|rec.approval_role.level if rec.approval_role.present? && rec.approval_role.level <=max_level }
            # req_lvl =  ApprovalRole.find_by_sql("select distinct(ta.level) from approval_roles ta, nanba_services p, approval_role_users ar where ar.project_id=#{project.id} and p.id=ar.inia_project_id and ta.level <= #{max_level} and ar.approval_role_id =ta.id").map(&:level)
            max_level > (cur_level) ?  req_lvl.compact.count>=max_level : true
          end



#------------------------------------------------------------------

          def make_sure_tickets?
            approval_level = require_user_approval_level(self)
            project = IniaProject.find(self.ticketing_approval.project_id)
            current_usr_level = 0
            last_level = get_current_user_role(project)
            level_array = [:a0, :a1, :a2, :a3, :a4, :a5, :a6]
            level_array.each_with_index do |rec, level|
              current_usr_level = level if level_array.include? rec
              break if rec == last_level
            end if !last_level.nil?
            p current_usr_level
            # raise

            index = approval_level.index(current_usr_level)
            index_val = index==nil ? 0 : index +1
            nxt_index = approval_level[index_val]==nil ? 0 : approval_level[index_val]
            waiting_status = IssueStatus.find_by_name('Waiting for approval')

            p last_level, current_usr_level, nxt_index
            p '---------- level ---- ext ====='
            if current_usr_level >= nxt_index
        interruption = self.category_approval_config.interruptions
              p '==== ram ===='
              if interruption.present?
                p '========= interr daa ====='
                level = 'a' << (nxt_index).to_s
                interruption.each do |rec|
                    self.assigned_to_id = rec.user_id
                    cur_lvl = rec.level.scan(/\d/).join('').to_i
                    interrupt_level = rec.interruption_type == 'override' ?  (cur_lvl - 1).to_s : cur_lvl.to_s
                    p '======== am level ===='
                    self.ticketing_approval.update_attributes(status: 'a'+interrupt_level)
                    break
                end if interruption.present?
                self.status_id = waiting_status.id
                self.pre_status_id = waiting_status.id
              else
              p '==== thiyagu -----'
                self.assigned_to_id = TicketingApproval.set_assignee_value(self)
                status = IssueStatus.find_by_name('open')
                self.ticketing_approval.update_attributes(:status => 'approved')
                old_status = IssueStatus.find_by_name('waiting for approval')
                if self.project.enabled_modules.map(&:name).include?('redmine_issue_sla')
                  SlaTime.create(:issue_id => self.id, :issue_sla_status_id => status.id,:user_id => self.assigned_to_id,  :old_status_id => old_status.id , :pre_status_duration => 0 )
                end
                self.status_id = status.id
                self.pre_status_id = self.status_id_was
                self.ticketing_approval.update_attributes(status: '')
              end
              self.save

             # self.send(:update_without_callbacks)
            else
              level = 'a' << (nxt_index).to_s
        interruption = self.category_approval_config.interruptions
              flag = 0
              if interruption.present?
                interrupt = interruption.order('level').first
                if ('a'+nxt_index.to_s) >= interrupt.level
                   self.assigned_to_id = interrupt.user_id
                   latest_lvl = interrupt.level
                   cur_lvl = latest_lvl.scan(/\d/).join('').to_i
                   interrupt_level = interrupt.interruption_type == 'intermediate' ?  (cur_lvl - 1).to_s : cur_lvl.to_s
                   p '======== am level ===='
                   p ['a'+interrupt_level,interrupt.level,cur_lvl,(cur_lvl - 1).to_s ]
                   self.ticketing_approval.update_attributes(status: 'a'+interrupt_level)

                  flag = 1
                end
              end

              if flag == 0
                p '========= 3 =============='
                p project, level
                assignee = get_user_role(project, level)
                current_usr_level  = get_approval_user_role(project, assignee)
                self.assigned_to_id = assignee.to_s
                self.ticketing_approval.update_attributes(status: current_usr_level.to_s)
              end
              self.status_id = waiting_status.id
              self.pre_status_id = waiting_status.id
              self.save
            end
              p '====== current_usr_level =========='
              p current_usr_level
          end

          def get_user_role(project, role)
            project.inia_members.each do |member|
              member.roles.each do |r|
               return member.user_id if r.permissions.include?(role.to_sym)
              end
            end
          end

          def get_approval_user_role(project, user_id)
            permissions = []
            project = IniaProject.find(project) if project.is_a? Integer
            p project,project, user_id
            p '===== call'
            member = project.inia_members.find_by_user_id(user_id)
            member.roles.each { |rec| permissions << rec.permissions } if member.present?
            ( permissions.flatten & [:a1, :a2, :a3, :a4, :a5, :a6]).sort.last
          end

          def get_current_user_role(project)
            permissions = []
            project = IniaProject.find(project) if project.is_a? Integer
            member = project.inia_members.find_by_user_id(User.current.id)
            member.roles.each { |rec| permissions << rec.permissions } if member.present?
            ( permissions.flatten & [:a1, :a2, :a3, :a4, :a5, :a6]).sort.last
          end

          def require_user_approval_level(issue)
            approval = issue.category_approval_config
            approval_array = []
            [approval.a0, approval.a1, approval.a2, approval.a3, approval.a4, approval.a5, approval.a6].each_with_index do |rec, level|
              approval_array << level if rec == true
            end
            approval_array
          end

          def require_approval_level(issue)
            approval = issue.category_approval_config
            approval_level = 0
            [approval.a0, approval.a1, approval.a2, approval.a3, approval.a4, approval.a5, approval.a6].each_with_index do |rec, level|
              approval_level = level  if rec == true
            end
            approval_level
          end

          def push_external_tag_tickets(status)
            if self.ticket_tag.present? && !(self.ticket_tag.internal rescue true)
              p '==== 1= ========'
              key = Redmine::Configuration['iServ_api_key']
              base_url = Redmine::Configuration['iServ_url']
              url = base_url+"/services/message/sync"
              emp_id = UserOfficialInfo.find_by_user_id(self.author_id).employee_id
              name = self.ticket_tag.name
              cat_name = self.ticket_tag.project_category.cat_name
              params = {
                  :serviceId => "updateDeductionTicketStatus",
                  :input=> {:employeeId=>  emp_id,:ticketId=> self.id,:categoryName=> cat_name,
                            :ticketSubject=> name, :description=> self.description,
                            :requestdate=> self.created_on,:status=> status}.to_json}.to_json
              begin
                code_name = RestClient::Request.execute(:method => :post,:url => url,
                                                          :payload =>params ,:headers => {'Accept' => :json, 'Content-Type' => 'application/json','Auth-key' => key },:verify_ssl => false)
              rescue RestClient::Exception => e
                puts e.http_body
              end
            end
          end

        end
      end
      
    end
  end
end