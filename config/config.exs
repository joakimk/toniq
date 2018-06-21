use Mix.Config

# NOTE: This config is only used for this project, it's not inherited when you use this library within an app. Put such defaults in Toniq.Config.

if Mix.env == :test do
  # Using the second database /1 for tests, but pubsub still uses the regular database
  # due to limitations in :eredis.
  config :toniq,
    redis_url: "redis://localhost:6379/1",
    keepalive_interval: 50, # ms
    keepalive_expiration: 70, # ms
    persistence: Toniq.RedisJobPersistence,
    takeover_interval: 100, # ms
    job_import_interval: 100, # ms
    retry_strategy: Toniq.RetryWithoutDelayStrategy
end

if Mix.env == :dev do
  # Running Toniq.TestWorker with the regular retry strategy is a bit too slow.
  config :toniq,
    retry_strategy: Toniq.RetryWithoutDelayStrategy,
    persistence: Toniq.RedisJobPersistence
end
