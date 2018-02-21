module SettingsControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      def plugin
        @plugin = Redmine::Plugin.find(params[:id])
        unless @plugin.configurable?
          render_404
          return
        end
        if request.post?
          Setting.send "plugin_#{@plugin.id}=", params[:settings]
          wktime_helper = Object.new.extend(WktimeHelper)
          #wktime_helper.sendNonLogTimeMail()
          #wktime_helper.lock_unlock_users()
          flash[:notice] = l(:notice_successful_update)
          redirect_to plugin_settings_path(@plugin)
        else
          @partial = @plugin.settings[:partial]
          @settings = Setting.send "plugin_#{@plugin.id}"
        end
      rescue Redmine::PluginNotFound
        render_404
      end
      end
      #alias_method_chain :show, :plugin # This tells Redmine to allow me to extend show by letting me call it via "show_without_plugin" above.
      # I can outright override it by just calling it "def show", at which case the original controller's method will be overridden instead of extended.
    end
  end


