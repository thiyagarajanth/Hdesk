class IniaMember < ActiveRecord::Base
  # establish_connection "sync_prod"

  after_destroy :cleanup

  def cleanup
    ApprovalRoleUser.where(:user_id => self.user_id, :inia_project_id => self.project_id).destroy_all
    tickets = Issue.find_by_sql("SELECT s.id FROM issues s join issue_ticket_tags it on s.id=it.issue_id  join issue_sla_statuses ss on s.status_id=ss.issue_status_id where ss.approval_sla=true and s.assigned_to_id=#{self.user_id} and it.inia_project_id=#{self.project_id} group by s.status_id").map(&:id)
    if tickets.present?
      #url = "http://192.168.4.87:4000/tickets/role-cleanup?user_id=#{self.user_id}&project_id=#{self.project_id}"
      key = ActiveRecord::Base.configurations['env']['iServ_api_key']
      base_url = ActiveRecord::Base.configurations['env']['inia_url']
      require 'json'
      require 'rest_client'
      url = base_url+"/tickets/role-cleanup?user_id=#{self.user_id}&project_id=#{self.project_id}"
      begin
        response = RestClient::Request.execute(:method => :get,:url => url,:verify_ssl => false)
      rescue RestClient::Exception => e
        response = ["result" => '']
        puts e.http_body
      end
    end
  end


end