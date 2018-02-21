Rails.configuration.to_prepare do
  p '========== test ddd======='
  Rails.logger.info '=================== forked -----------'   
  require 'rufus-scheduler'
  p '==== test ===='
  if defined?(PhusionPassenger)
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
      Rails.logger.info '=================== forked -----------'   
        if forked
          count = 0
          scheduler = Rufus::Scheduler.new
          scheduler.every '5s' do
            count = count + 1
            p '============ called sync ---------here---'
              Synch.sync_sql
              Rails.logger.info "-----------------------#{count}-------------"
          end
        end
    end
  end
end