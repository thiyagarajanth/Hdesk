Redmine::Plugin.register :cas do
  name 'Cas plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'
end


Rails.configuration.to_prepare do
  require_dependency 'account_controller_override_patch'
   require_dependency 'application_controller_override_patch'
end

AccountController.send(:include, AccountControllerOverridePatch)
 ApplicationController.send(:include, ApplicationControllerOverridePatch)

  # enable detailed CAS logging
  # cas_logger = CASClient::Logger.new('log/cas.log')
  # cas_logger.level = Logger::DEBUG


# CAS::Filter.login_url = "https://192.168.8.103:8443/cas/login"  # the URI of the CAS login page
# CAS::Filter.validate_url = "https://192.168.8.103:8443/cas/serviceValidate"  # the URI where CAS ticket validation requests are sent
# CAS::Filter.server_name = "http://192.168.11.116/"  # the server name of your CAS-protected application
# CAS::Filter.renew = false                      # force re-authentication? see http://www.ja-sig.org/products/cas/overview/protocol
# CAS::Filter.wrap_request = true                # make the username available under request.username?
# CAS::Filter.gateway = false                    # act as cas gateway? see http://www.ja-sig.org/products/cas/overview/protocol
# CAS::Filter.session_username = :casfilteruser

  CASClient::Frameworks::Rails::Filter.configure(
      :cas_base_url  => Redmine::Configuration['sangam_url'],#"https://sangamstaging.objectfrontier.com/",
      :enable_single_sign_out => true
  )
