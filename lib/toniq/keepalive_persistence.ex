defmodule Toniq.KeepalivePersistence do
  def register_vm(identifier) do
    redis_query(["SADD", registered_vms_key(), identifier])
  end

  def update_alive_key(identifier, keepalive_expiration) do
    # Logger.log(:debug, "Updating keepalive for #{state.identifier} #{inspect(debug_info)}")
    redis_query(["PSETEX", alive_key(identifier), keepalive_expiration, debug_info()])
  end

  def registered_vms do
    redis_query(["SMEMBERS", registered_vms_key()])
  end

  def alive?(identifier) do
    alive_vm_debug_info(identifier) != :undefined
  end

  def alive_vm_debug_info(identifier) do
    redis_query(["GET", alive_key(identifier)])
  end

  def takeover_jobs(from_identifier, to_identifier) do
    redis()
    |> Exredis.query_pipe([
      # Begin transaction
      ["MULTI"],

      # Copy orphaned jobs to incoming jobs
      #
      # We copy jobs to incoming jobs so that they will be
      # enqueued and run in this vm. Data in redis is just
      # a backup, we only poll for incoming jobs.
      [
        "SUNIONSTORE",
        incoming_jobs_key(to_identifier),
        jobs_key(from_identifier),
        incoming_jobs_key(from_identifier),
        incoming_jobs_key(to_identifier)
      ],

      # Move failed jobs
      [
        "SUNIONSTORE",
        failed_jobs_key(to_identifier),
        failed_jobs_key(from_identifier),
        failed_jobs_key(to_identifier)
      ],

      # Move delayed jobs
      [
        "SUNIONSTORE",
        delayed_jobs_key(to_identifier),
        delayed_jobs_key(from_identifier),
        delayed_jobs_key(to_identifier)
      ],

      # Remove orphaned job lists
      [
        "DEL",
        jobs_key(from_identifier),
        failed_jobs_key(from_identifier),
        delayed_jobs_key(from_identifier),
        incoming_jobs_key(from_identifier)
      ],

      # Deregister missing vm
      [
        "SREM",
        registered_vms_key(),
        from_identifier
      ],

      # Execute transaction
      ["EXEC"]
    ])
  end

  # Added so we could use it to default scope further out when we want to allow custom persistance scopes in testing.
  def default_scope, do: Application.get_env(:toniq, :redis_key_prefix)

  defp incoming_jobs_key(identifier) do
    Toniq.JobPersistence.incoming_jobs_key(identifier)
  end

  defp jobs_key(identifier) do
    Toniq.JobPersistence.jobs_key(identifier)
  end

  defp failed_jobs_key(identifier) do
    Toniq.JobPersistence.failed_jobs_key(identifier)
  end

  defp delayed_jobs_key(identifier) do
    Toniq.JobPersistence.delayed_jobs_key(identifier)
  end

  defp redis_query(query) do
    redis() |> Exredis.query(query)
  end

  defp redis do
    :toniq_redis
    |> Process.whereis
  end

  # This is not a API any production code should rely upon, but could be useful
  # info when debugging or to verify things in tests.
  defp debug_info, do: %{ system_pid: System.get_pid,
                          last_updated_at: system_time() }

  # R17 version of R18's :erlang.system_time
  defp system_time, do: :timer.now_diff(:erlang.now, {0, 0, 0}) * 1000

  defp alive_key(identifier), do: "#{default_scope()}:#{identifier}:alive"
  defp registered_vms_key,    do: "#{default_scope()}:registered_vms"
end
