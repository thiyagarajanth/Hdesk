require 'redmine'


require_dependency 'issues_controller_patch'
IssuesController.send(:include, IssuesControllerPatch)
require_dependency 'timelog_controller_patch'
TimelogController.send(:include, TimelogControllerPatch)
require_dependency 'wktime_controller_patch'
WktimeController.send(:include, WktimeControllerPatch)

Redmine::Plugin.register :sla_reports do
  name 'Sla Reports plugin'
  author 'OFS Tech'
  description 'Report for Response, Resolution SLA and resolved, approved tickets visibility'
  version '0.0.1'

  def permission_checker(permission)
    proc {

      access = []
      Member.where(user_id: User.current.id).each { |member|
        member.roles.each { |role|
          access << role.permissions.include?(permission.to_sym)
        }
      }
      User.current.admin? || access.include?(true)
    }
  end
  project_module :sla_reports do
    permission :sla_reports, { :sla_reports => [:index,:user_request_validity] }, :public => true
    permission :sla_reports, { :sla_reports => [:index] }, :require => :member
    permission :view_resolved_tickets, { :sla_reports => [:index] }, :require => :member
  end
  #commented below block for the purpose of hereafter whole application needs to run in actual SLA
  project_module :timelog_sla do
    permission :timelog_sla, { :sla_reports => [:index] }, :require => :member
  end
  menu :project_menu, :reports, { :controller => 'sla_reports', :action => 'index' }, :caption => 'Reports', :before => :wiki, :param => :project_id

end



 RedmineApp::Application.config.after_initialize do
   require 'sla_reports/infectors/issue_query'
   require 'sla_reports/infectors/query'
 end

Rails.configuration.to_prepare do
  require 'sla_reports/infectors/issue_query'
  require 'sla_reports/infectors/query'
  require_dependency 'sla_reports/infectors'
end

Rails.configuration.to_prepare do
  require 'rufus/scheduler'
  helper = Object.new.extend(SlaReportsHelper)
  if defined?(PhusionPassenger)
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
      Rails.logger.info "-----Job called at----#{Time.now}--------------#{}-------------"
      if forked && Redmine::Configuration['backGroudJobPort'].present?
        scheduler = Rufus::Scheduler.new
        scheduler.cron(Redmine::Configuration['slaReportTime']) do
          helper.sla_report_mail
        end
        scheduler.cron '32 14 * * *' do
          helper.send_job_status_notification('Started')
          helper.request_remainder
          helper.send_job_status_notification('End')
        end
        scheduler.cron '32 14,03,04 *   *   * ' do
          helper.retry_remainder
        end
      end
    end
  else
    scheduler = Rufus::Scheduler.new
    # scheduler.cron(Redmine::Configuration['slaReportTime']) do
    #   p "============ #{} ---------#{Time.now}---"
    #   helper.sla_report_mail
    # end
    scheduler.cron '18 16 * * *' do
      # helper.send_job_status_notification('Started')
      helper.request_remainder
      # helper.send_job_status_notification('End')
    end
    scheduler.cron '35 14,03,04 *   *   * ' do
      p '-------------called-retry--'
      helper.retry_remainder
    end
  end



end

