class DefaultAssigneeSetupController < ApplicationController
  unloadable


  before_filter :find_project

  def index

    @trackers  = @project.trackers
    @messages = []
    @default_assignees = DefaultAssigneeSetup.where(:project_id=>@project.id)
    if request.xhr?
      requests = []
      users = @project.assignable_users
      requests = users.map { |e|  [e[:id],  (e[:firstname] +' '+e[:lastname])] }
      render :json => {result: requests }
    end
  end

  def create
  @default_assignee = DefaultAssigneeSetup.find_or_initialize_by_project_id_and_tracker_id(:project_id=> params[:project_id],:tracker_id=>params[:tracker_id])
  @default_assignee.default_assignee_to = params[:assigneed_to_id]
  # default_assignee = DefaultAssigneeSetup.where(:project_id => params[:project_id],:tracker_id => params[:tracker_id]).update_all(:default_assignee_to => params[:assigneed_to_id])
    if @default_assignee.save
       flash[:notice] = l(:notice_successful_update)
       redirect_to settings_project_path(@project, :tab => 'default_assignee')
    else
      @trackers  = @project.trackers
      @members  = @project.users
      render :index
     @messages = []
    end
  end

  def edit
    assignee = DefaultAssigneeSetup.find(params[:id])
    redirect_to settings_project_path(@project, :tab => 'default_assignee', :assigneed_to_id => assignee.default_assignee_to, :tracker_id => assignee.tracker_id)
  end

  def destroy
    DefaultAssigneeSetup.where(:default_assignee_to => params[:id]).update_all(:default_assignee_to => nil)
    # assignee = DefaultAssigneeSetup.find(params[:id])
    #  assignee.destroy
  redirect_to settings_project_path(@project, :tab => 'default_assignee')
  end

  def status_configuration
     status = params[:status_id]
     assignees = params[:assignee]
     display  = params[:display_overview]
     if params[:tracker_ids].present?
       assignees.each_with_index do |assignee,i|
         if assignee.present?
           default_assignee_setup = DefaultAssigneeSetup.find_or_initialize_by_project_id_and_tracker_id_and_status_id(params[:project_id],params[:tracker_ids],status[i])
           default_assignee = DefaultAssigneeSetup.find_by_project_id_and_tracker_id(params[:project_id],params[:tracker_ids]).default_assignee_to
           default_assignee_setup.assignee = assignee
           default_assignee_setup.default_assignee_to = default_assignee
           default_assignee_setup.display_in_overview = display.include?(default_assignee_setup.status.name) ? true : false
           default_assignee_setup.save(validate: false)
           flash[:notice] = l(:notice_successful_update)
         end
       end
     else
       render :index
     end
     redirect_to settings_project_path(@project, :tab => 'default_assignee')
  end


  private

  def find_project

    #params[:project_id] = 1
    @project = Project.find(params[:project_id])
  end

end
