module GroupsControllerPatch
  def self.included(base)
    base.class_eval do
		  before_filter :require_admin
		  before_filter :find_group, :except => [:index, :new, :create]
		  accept_api_auth :index, :show, :create, :update, :destroy, :add_users, :remove_user

		  helper :custom_fields
      def create
		    @group = Group.new
		    @group.safe_attributes = params[:group]
				
		    respond_to do |format|
		      if @group.save
		      	entity = SyncEntity.find_or_initialize_by_entity_and_entity_id('groups', @group.id)
						entity.ref_entity='users'
						entity.can_sync = params[:group][:add_user]
						entity.save
		        format.html {
		          flash[:notice] = l(:notice_successful_create)
		          redirect_to(params[:continue] ? new_group_path : groups_path)
		        }
		        format.api  { render :action => 'show', :status => :created, :location => group_url(@group) }
		      else
		        format.html { render :action => "new" }
		        format.api  { render_validation_errors(@group) }
		      end
		    end
		  end

		  def update
		    @group.safe_attributes = params[:group]
				entity = SyncEntity.find_or_initialize_by_entity_and_entity_id('groups', @group.id)
				entity.ref_entity='users'
				entity.can_sync = params[:group][:add_user]
				entity.save
		    respond_to do |format|
		      if @group.save
		        flash[:notice] = l(:notice_successful_update)
		        format.html { redirect_to(groups_path) }
		        format.api  { render_api_ok }
		      else
		        format.html { render :action => "edit" }
		        format.api  { render_validation_errors(@group) }
		      end
		    end
      end
      def user_count_by_group_id
        h = User.active.joins(:groups).group('group_id').count
        h.keys.each do |key|
          h[key.to_i] = h.delete(key)
        end
        h
      end
	  end
	end
end