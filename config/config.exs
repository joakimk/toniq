use Mix.Config

# keepalive_interval: The time between each time the vm reports in as being alive
# keepalive_expiration: The time until other vms can take over jobs from a stopped vm

if Mix.env == :test do
  # Using the second database /1 for tests, but pubsub still uses the regular database
  # due to limitations in :eredis.
  config :toniq,
    redis_url: "redis://localhost:6379/1",
    keepalive_interval: 50, # ms
    keepalive_expiration: 70 # ms
else
  config :toniq,
    redis_url: "redis://localhost:6379/0",
    keepalive_interval: 5000, # ms
    keepalive_expiration: 10000 # ms
end
