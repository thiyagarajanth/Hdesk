require File.expand_path('../boot', __FILE__)

require 'rails/all'
require 'rubygems'
require 'rake'
require 'rufus/scheduler'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(:assets => %w(development test)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module SyncApp
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    config.active_record.whitelist_attributes = false

    # Enable the asset pipeline
    config.assets.enabled = true
    config.action_mailer.raise_delivery_errors = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
        address:   'mail1.object-frontier.com',
        port:  25,
        domain:  'itp.objectfrontier.com',
        user_name:   'nanba@object-frontier.com',
        password:   'Techn1cal',
        authentication:  :login,
        enable_starttls_auto: true  }


    
    config.after_initialize do
      count = 0
      helper = Object.new.extend(ApplicationHelper)
      if defined?(PhusionPassenger)
        PhusionPassenger.on_event(:starting_worker_process) do |forked|
        Rails.logger.info "-----Job called at----#{Time.now}--------------#{count}-------------"
        if forked
          scheduler = Rufus::Scheduler.new
          # scheduler.cron '00 01 * * *' do
          #   helper.send_job_status_notification('Started')
          #   helper.request_remainder
          #   helper.send_job_status_notification('End')
          # end
          # scheduler.cron '00 02,03,04 *   *   * ' do
          #   helper.retry_remainder
          # end
          scheduler.every '1m' do
          count = count + 1
          Sync.sync_sql
          Rails.logger.info "-----Job End at----#{Time.now}--------------#{count}-------------"
          end
        end
        end
      else
        scheduler = Rufus::Scheduler.new
        scheduler.every '2m' do
        count = count + 1
        p "============ #{count} ---------#{Time.now}---"
        Sync.sync_sql
        end
      end
    end
  end
end
