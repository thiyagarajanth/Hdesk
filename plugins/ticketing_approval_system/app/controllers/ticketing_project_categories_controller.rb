class TicketingProjectCategoriesController < ApplicationController
  unloadable

  accept_api_auth :index, :show, :create, :update, :destroy

  def index
    if request.xhr?
      project = Project.find_by_identifier(params[:project_id])
      categories = project.project_categories.where("cat_name like '%#{params[:term]}%'").map{|p| { id: p.id, text: p.cat_name} }
    end
    respond_to do |format|
      format.html { redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system')}
      format.json { render :json => {result: categories } }
      format.api { @categories = @project.issue_categories.all }
    end
  end

  def show
    if request.xhr?
      category = ProjectCategory.find(params[:id])
      render :json => {:name => category.cat_name, :id => category.id, :need_approval => category.need_approval, :dashboard_visibility => category.dashboard_visibility }
    end

  end

  def new
    @project = Project.find_by_identifier(params[:project_id])
    @category = @project.project_categories.build
    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    @project = Project.find_by_identifier(params[:project_id])
    @category = @project.project_categories.build(params[:ticketing_project_categories])
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
        format.html { render :action => 'new'}
        format.js   { render :action => 'new'}
        format.api { render_validation_errors(@category) }
      end
    end
  end

  def edit
    @project = Project.find_by_identifier(params[:project_id])
    @category = @project.project_categories.build
    respond_to do |format|
      format.html
      format.js
    end
  end

  def update
    @project = Project.find_by_identifier(params[:project_id])
    @category = ProjectCategory.find(params[:id])
    value = @category.need_approval == true ? '1' : '0'
    max =  (value=='1' && value != params[:ticketing_project_categories][:need_approval] && @category.category_approval_configs.present?)
    if max
      @category.errors[:base] << "This Category associated with some approvals."
    end
    if !max && @category.update_attributes(params[:ticketing_project_categories])
      respond_to do |format|
        format.html do
          flash[:notice] = l(:notice_successful_create)
          redirect_to settings_project_path(params[:project_id], :tab => 'ticketing_approval_system')
        end
        format.js
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit',:project_id =>params[:project_id], :id => params[:id] }
        format.js   { render :action => 'edit',:project_id =>params[:project_id], :id => params[:id] }
        format.api { render_validation_errors(@category) }
      end
    end
  end

  def destroy
    category = ProjectCategory.find(params[:id])
    count = category.ticket_tags.count
    if count < 1
      category.destroy
      render :json => {:file_content => 'okay'}
    else
      render :json => {:file_content => 'fails' }
    end
  end

  def add_access_users
    @project = IniaProject.find(params[:project_id])
   if params[:issue_id].present?
    @issue = Issue.find(params[:issue_id])
   end
   @users = users_for_new_watcher
  end

  def users_for_new_watcher
    if params[:q].blank? && @project.present?
      users = @project.users
    else
      users = User.find_by_sql("select u.id,u.firstname,u.lastname,u.login from users u join inia_members im on im.user_id=u.id where u.status=1 and im.project_id in (#{@project.id}) and (u.firstname LIKE '%#{params[:q]}%' OR u.lastname LIKE '%#{params[:q]}%' OR u.login LIKE '%#{params[:q]}%') ").uniq
      # users = @project.users.where("firstname LIKE ? OR lastname LIKE ? OR login LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%","%#{params[:q]}%")
    end
    users
  end

  def autocomplete_for_user
    @project = IniaProject.find(params[:project_id])
    @users = users_for_new_watcher
    render :layout => false
  end

  def append
    if params[:access_users].is_a?(Hash)
      user_ids = params[:access_users][:user_ids] || [params[:access_users][:user_id]]
      @users = User.active.where(:id => user_ids).all
    end
    if @users.blank?
      render :nothing => true
    end
  end


  def update_access_users
    @issue = Issue.find(params[:issue_id])
    @duplicate_access_users = @issue.dup
    last_users = @issue.access_users

    if params[:issue][:user_access_user_ids].present?
      params[:issue][:user_access_user_ids] = params[:issue][:user_access_user_ids].reject(&:empty?)
      access_users = params[:issue][:user_access_user_ids].present? ?  params[:issue][:user_access_user_ids].compact : []
      @issue.access_users= access_users
      if @issue.save
        dup_access_users = @duplicate_access_users.present? ?
        @duplicate_access_users.access_users : []
        issue_access_users = @issue.present? ? @issue.access_users : []
        added_users = dup_access_users - issue_access_users
        removed_users = issue_access_users - dup_access_users
        @access_user_names=""
        @access_added_user_names=""
        @access_removed_user_names = ""
        if added_users.present?
          @users = User.where(:id=>added_users)
          @users.each_with_index do |each_user,index|
            @access_added_user_names = @access_added_user_names + ' ' +  "#{each_user.firstname + ' ' + each_user.lastname}" +' '+ '('+
                      "#{each_user.employee_id}" + ')' + "#{(((index.to_i) < @users.count) ) ? ',' : '' }"
          end
          @access_added_user_names = @access_added_user_names + " Removed."
        end
        if removed_users.present?
          @users = User.where(:id=>removed_users)
          @users.each_with_index do |each_user,index|
            @access_removed_user_names = @access_removed_user_names + '  ' + "#{each_user.firstname + ' ' + each_user.lastname}" +' '+ '('+
                    "#{each_user.employee_id}" + ')' + "#{(((index.to_i) < @users.count) ) ? ',' : '' }"
            end
            @access_removed_user_names=@access_removed_user_names+ " Added."
        end
      end
    end

    if @issue.access_users.present? && (@access_added_user_names.present? || @access_removed_user_names.present?)
      issue_journal = Journal.new(:journalized_id => @issue.id, :user_id => User.current.id,
                                  :journalized_type => "Issue", :notes => "Access users:  #{@access_added_user_names} , #{@access_removed_user_names} ")
      issue_journal.save
    end

    #below block is to update histories for deleted single and multiple access users
    if last_users.present? && @issue.access_users.empty?
      @users = User.where(:id=>last_users)
      @users.each_with_index do |each_user,index|
        @access_removed_user_names = @access_removed_user_names + '  ' + "#{each_user.firstname + ' ' + each_user.lastname}" +' '+ '('+
            "#{each_user.employee_id}" + ')' + "#{(((index.to_i) < @users.count) ) ? ',' : '' }"
      end
      @access_removed_user_names=@access_removed_user_names+ " removed."
      issue_journal =
          Journal.new(:journalized_id=>@issue.id,:user_id=>User.current.id,:journalized_type=>"Issue",:notes=>"Access users:   #{@access_removed_user_names} ")
      issue_journal.save
    end
    flash[:notice]="Access users successfully Updated."
    redirect_to issue_path(@issue)
  end
end
