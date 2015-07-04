use Mix.Config

# Using the second database /1 for tests, but pubsub still uses the regular database
# due to limitations in :eredis.
if Mix.env == :test do
  config :toniq, redis_url: "redis://localhost:6379/1"
else
  config :toniq, redis_url: "redis://localhost:6379/0"
end
