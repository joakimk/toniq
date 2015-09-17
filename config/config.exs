use Mix.Config

# keepalive_interval: The time between each time the vm reports in as being alive
# keepalive_expiration: The time until other vms can take over jobs from a stopped vm
# redis_key_prefix: The prefix that will be added to all redis keys used by toniq. You will want to customize this if you have multiple applications using the same redis server. Keep in mind though that redis servers consume very little memory, and running one per application guarantees there is no coupling between the apps.

config :toniq,
  redis_key_prefix: :toniq

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
