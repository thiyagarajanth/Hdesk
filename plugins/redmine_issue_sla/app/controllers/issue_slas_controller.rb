# Sample plugin controller
class IssueSlasController < ApplicationController
  unloadable

  before_filter :find_project_by_project_id
  before_filter :authorize, :only => :update

  def update
    #call method to add severioty to project
    @tracker = Tracker.find(params[:tracker_id])
    params[:updated_at]=Time.now
    ApproverSla.create_or_update(@project, params)
    IssueSlaStatus.create_or_update_status(@project, params)
    SlaWorkingDay.update_working_hr_day(@project, params)
    IssueSla.create_slas(@project, params)
    IssueSla.create_or_update_response_time(@project,params)
    flash[:notice] = l(:notice_successful_update)
    redirect_to settings_project_path(@project, :tab => 'issue_sla',:tracker_id=>params[:tracker_id])
  end

  def add_response_sla
    @issue = Issue.find(params[:issue_id])
    @response = ResponseTime.find_or_initialize_by_issue_id(@issue.id)
    @response.user_id = User.current.id
    @response.user_id = User.current.id
    @response.comment = params[:comment]
    if @issue.project.response_sla.present?
      r_time = @issue.project.response_sla.response_set_time
      hh = r_time.to_s.split(/\./).first.to_i
      mm = r_time.to_s.split(/\./).last
      mm = mm.size == 1 ? mm.to_i * 10 : mm.to_i
      minutes = (hh * 60) + mm
      dur = ((Time.now.utc -  @issue.created_on.utc.to_time)/60).to_i
      h,m = dur.divmod(60)
      m = m.to_s.size == 1 ? "0#{m}" : m
      @response.duration = "#{h}.#{m}"
      @response.status =  minutes >= dur
    else
      @response.duration = '0.0'
      @response.status =  false
    end
      name = User.current.firstname
    if @response.save
      sendResponseEmail
        render :json => [@response,name,params[:comment]]
    end
  end


  def sendResponseEmail
    raise_delivery_errors_old = ActionMailer::Base.raise_delivery_errors
    ActionMailer::Base.raise_delivery_errors = true
    begin
      @test = SlaMailer.sendResponseEmail(User.current,@issue, @response).deliver
    rescue Exception => e
      # flash[:error] = l(:notice_email_error, e.message)
    end
    ActionMailer::Base.raise_delivery_errors = raise_delivery_errors_old

  end

end
