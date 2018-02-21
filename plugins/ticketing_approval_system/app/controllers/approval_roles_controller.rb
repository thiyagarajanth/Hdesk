class ApprovalRolesController < ApplicationController
  
  accept_api_auth :index, :show, :create, :update, :destroy

  def new
    @project = Project.find_by_identifier(params[:project_id])
    @category = @project.approval_roles.build
    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    @project = Project.find_by_identifier(params[:project_id])
    @category = @project.approval_roles.new(params[:project_approval_roles])    
    if @category.save
      respond_to do |format|
        format.html do
          flash[:notice] = l(:notice_successful_create)
          redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system')
        end
        format.js
      end
    else
      respond_to do |format|
        format.html do 
        	flash[:error] = @category.errors.full_messages.to_sentence        	
        	redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system', :name =>@category.name,:level => @category.level)
         end
      end
    end
  end

  def edit
  	@ticket = ApprovalRole.find(params[:id])
    redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system', :name => @ticket.name, :level => @ticket.level, :approval_id=> @ticket.id, :restrict => @ticket.can_restrict)
  end

  def update
    @ticket = ApprovalRole.find(params[:project_approval_roles][:id])
    if @ticket.update_attributes(params[:project_approval_roles])
      respond_to do |format|
        format.html do
          flash[:notice] = 'Successfully updated.'
          redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system')
        end
        format.js
      end
    else
      respond_to do |format|
        format.html do 
        	flash[:error] = @category.errors.full_messages.to_sentence        	
        	redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system', :name =>@category.name,:level => @category.level)
         end
      end
    end
  end

  def destroy
     approval = ApprovalRole.find(params[:id])
     tk = TicketApproval.where(:approval_role_id => params[:id]).map(&:id)
     tk1 = TicketApproval.where(:ref_id => tk).map(&:id)
     state = TicketApprovalFlow.where(:ticket_approval_id => (tk+tk1)).map(&:status)
    if !state.include?('pending') && approval.delete
     TicketApproval.where(:id => (tk+tk1)).delete_all
     respond_to do |format|
      format.html do 
        	flash[:notice] = 'Approval role was deleted Successfully.'
        	redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system')
       end    
   	 end
    else
     respond_to do |format|
      format.html do 
        	flash[:error] = 'This role have some pending tickets for approval.'
        	redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system')
       end    
      end
    end
  end

end