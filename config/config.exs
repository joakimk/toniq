use Mix.Config

# Using the second database /1 for tests, but pubsub still uses the regular database
# due to limitations in :eredis.
config :exqueue, redis_url: "redis://localhost:6379/1"
