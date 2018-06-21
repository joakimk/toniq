# There is no default config system in Elixir yet, but this workaround seems to work.
defmodule Toniq.Config do
  def init do
    # keepalive_interval: The time between each time the vm reports in as being alive.
    # keepalive_expiration: The time until other vms can take over jobs from a stopped vm.
    # takeover_interval: The time between checking for orphaned jobs originally belonging to other vms to move to incoming_jobs.
    # job_import_interval: The time between checking for incoming_jobs to enqueue and run.
    # redis_key_prefix: The prefix that will be added to all redis keys used by toniq. You will want to customize this if you have multiple applications using the same redis server. Keep in mind though that redis servers consume very little memory, and running one per application guarantees there is no coupling between the apps.
    default(
      :toniq,
      redis_key_prefix: :toniq,
      redis_url: "redis://localhost:6379/0",
      persistence: Toniq.RedisJobPersistence,
      retry_strategy: Toniq.RetryWithIncreasingDelayStrategy,

      # time in milliseconds
      keepalive_interval: 4_000,
      keepalive_expiration: 10_000,
      takeover_interval: 2_000,
      job_import_interval: 2_000,
      delay_flush_interval: 100
    )
  end

  defp default(scope, options) do
    Enum.each(options, fn {key, value} ->
      # IO.inspect key: key, value: value
      unless Application.get_env(scope, key) do
        # IO.inspect "using default"
        :ok == Application.put_env(scope, key, value)
      end
    end)
  end
end
