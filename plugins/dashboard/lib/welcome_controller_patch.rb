module WelcomeControllerPatch
	def self.included(base)
		base.class_eval do
			include ProjectsHelper
	    helper :projects
      include MyHelper
      helper :My
	        
			def index
				@news = News.latest User.current
			  @projects = Project.latest User.current
			  respond_to do |format|
  			  format.html {
  			 	scope = Project
  			  Project.active
  			 	unless params[:closed]
  			 	scope = scope.active
  				end
  			  @projects = scope.visible.order('lft').all
  				}
  		  end
 		  end
  	end
  end
end