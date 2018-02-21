module WelcomeControllerPatch
  def self.included(base)
    base.class_eval do
    	def exceptions
    	end
    end
  end
end
