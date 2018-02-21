module TicketingApprovalSystem
  module Infectors
    module Project
      module ClassMethods; end
  
      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          has_many :category_approval_configs, :class_name => 'CategoryApprovalConfig', :foreign_key => 'project_id'
          has_many :project_categories, :class_name => 'ProjectCategory', :foreign_key => 'project_id'
          has_many :ticketing_approvals#, :class => 'TicketingApproval', :foreign_key => 'project_id'
          has_many :non_approval_tickets
          has_many :approval_roles
          has_many :ticket_tags
          has_many :request_remainders
          has_many :team_profiles
          has_many :time_entry_activities
          has_many :members, :include => [:principal, :roles], :conditions => "#{Principal.table_name}.type='User' AND #{Principal.table_name}.status=#{Principal::STATUS_ACTIVE}"
          has_many :memberships, :class_name => 'Member'
          has_many :member_principals, :class_name => 'Member',
                   :include => :principal,
                   :conditions => "#{Principal.table_name}.status=#{Principal::STATUS_ACTIVE}"
          # has_many :delegation_audits
          has_many :approval_role_users
          has_many :default_assignee_setups



          def get_team_members
            # self.team_profiles.map(&:user)
            users = User.find_by_sql("select u.* from users u
            join members m on m.user_id=u.id
            join member_roles mr on mr.member_id=m.id
            join roles r on r.id=mr.role_id
            where r.permissions like '%log_time%' and m.project_id=#{self.id} and u.login is not null and u.type='User' and u.status=1 group by u.id ")
            users
          end

          def get_users_rating(id)
            count,avg = UserRating.find_by_sql("select count(*) as count, COALESCE(round(avg(rating),2),0) as avg from user_ratings where rated_for = #{id} and project_id=#{self.id}").map{|x|[x.count, x.avg.to_f]}.last
              # rating = UserRating.where(:rated_for => id, :project_id => self.id)
              # avg = rating.average(:rating) rescue 0
              # avg = avg.round(2) if avg.present?
              {:count => count, :avg => avg, :user_id => id}
          end

          def get_team_group
            types = []
            types << 'Group' if Setting.issue_group_assignment?

            member_principals.
                select {|m| types.include?(m.principal.type) && m.roles.detect(&:assignable?)}.
                map(&:principal).
                sort
          end

          def ticket_status_count(status)
            self.issues.where(:status_id => status).count
          end

          def return_team_and_group(issue)
            users = []
            users << get_team_members
            users << get_team_group
            users << issue.assigned_to if issue.id.present? && issue.assigned_to.present? && !users.flatten.include?(issue.assigned_to)
            users.flatten
          end

          def project_contact(field)
            self.custom_field_values.each_with_index do |c,index|
              custom_field =CustomField.where(:id=>c.custom_field_id)
              if custom_field.present? && (custom_field.last.name==field)
               return self.custom_field_values[index].to_s
              end
            end
          end
        end
      end
      
    end
  end
end