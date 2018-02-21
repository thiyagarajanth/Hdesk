module AttachmentsControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      before_filter :find_project, :except => [:upload, :attachments]
      before_filter :file_readable, :read_authorize, :only => [:show, :download, :thumbnail]
      before_filter :delete_authorize, :only => :destroy
      before_filter :authorize_global, :only => :upload

      accept_api_auth :show, :download, :upload

      def attachments
        # Make sure that API users get used to set this content type
        # as it won't trigger Rails' automatic parsing of the request body for parameters
        unless request.content_type == 'application/octet-stream'
          render :nothing => true, :status => 406
          return
        end

        @attachment = Attachment.new(:file => request.raw_post)
        @attachment.author = User.current
        @attachment.filename = params[:filename].presence || Redmine::Utils.random_hex(16)
        saved = @attachment.save

        respond_to do |format|
          format.js
          format.api {
            if saved
              render :action => 'upload', :status => :created
            else
              render_validation_errors(@attachment)
            end
          }
        end
      end

    end
  end
end



