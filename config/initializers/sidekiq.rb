Sidekiq.default_worker_options = {
  backtrace: false,
  # retry: false
}

redis_conn = proc {
  redis_connection = Redis.new(url: ENV['REDIS_URL'])
}


Sidekiq.configure_server do |config|
  config.redis = ConnectionPool.new(size: 150, &redis_conn)
end

Sidekiq.configure_client do |config|
  config.redis = ConnectionPool.new(size: 5, &redis_conn)
end

schedule_file = "config/schedule.yml"
if File.exist?(schedule_file) && Sidekiq.server?
  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
end

# SidekiqUniqueJobs.config.unique_args_enabled = true
