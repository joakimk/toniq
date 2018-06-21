defmodule Toniq.RedisAdapter do
  @moduledoc """
  Persistance Adapter for Redis

  ## Example config
      # In config/config.exs, or config.prod.exs, etc.
      config :toniq,
        persistence: Toniq.RedisJobPersistence
  """

  @behaviour Toniq.JobPersistenceAdapter

  import Exredis.Api
  alias Toniq.Job

  def store(job, type, identifier) do
    store_job_in_key(job, jobs_key(type, identifier), identifier)
  end

  def jobs_key(type, identifier) do
    identifier_scoped_key(type, identifier)
  end

  @doc """
  Returns all jobs
  """
  def fetch(type, identifier \\ default_identifier()) do
    load_jobs(jobs_key(type, identifier), identifier)
  end

  # Only used internally by JobImporter
  def remove_from_incoming_jobs(job, identifier \\ default_identifier()) do
    redis()
    |> srem(jobs_key(:incoming_jobs, identifier), prepare_for_redis(job))
  end

  @doc """
  Marks a job as finished. This means that it's deleted from redis.
  """
  def mark_as_successful(job, identifier \\ default_identifier()) do
    redis()
    |> srem(jobs_key(:jobs, identifier), prepare_for_redis(job))
  end

  @doc """
  Marks a job as failed. This removes the job from the regular list and stores it in the failed jobs list.
  """
  def mark_as_failed(job, error, identifier \\ default_identifier()) do
    job_with_error = Job.set_error(job, error)

    redis()
    |> Exredis.query_pipe([
      ["MULTI"],
      ["SREM", jobs_key(:jobs, identifier), prepare_for_redis(job)],
      ["SADD", jobs_key(:failed_jobs, identifier), prepare_for_redis(job_with_error)],
      ["EXEC"]
    ])

    job_with_error
  end

  @doc """
  Moves a failed job to the regular jobs list.

  Uses "job.vm" to do the operation in the correct namespace.
  """
  def move_failed_job_to_incoming_jobs(job_with_error) do
    job = Job.set_error(job_with_error, nil)

    redis()
    |> Exredis.query_pipe([
      ["MULTI"],
      ["SREM", jobs_key(:failed_jobs, job.vm), prepare_for_redis(job_with_error)],
      ["SADD", jobs_key(:incoming_jobs, job.vm), prepare_for_redis(job)],
      ["EXEC"]
    ])

    job
  end

  @doc """
  Moves a delayed job to the regular jobs list.

  Uses "job.vm" to do the operation in the correct namespace.
  """
  def move_delayed_job_to_incoming_jobs(delayed_job) do
    redis()
    |> Exredis.query_pipe([
      ["MULTI"],
      ["SREM", jobs_key(:delayed_jobs, delayed_job.vm), prepare_for_redis(delayed_job)],
      ["SADD", jobs_key(:incoming_jobs, delayed_job.vm), prepare_for_redis(delayed_job)],
      ["EXEC"]
    ])

    delayed_job
  end

  @doc """
  Deletes a failed job.

  Uses "job.vm" to do the operation in the correct namespace.
  """
  def delete_failed_job(job) do
    redis()
    |> srem(jobs_key(:failed_jobs, job.vm), prepare_for_redis(job))
  end

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
  defp default_scope, do: Application.get_env(:toniq, :redis_key_prefix)

  defp incoming_jobs_key(identifier) do
    jobs_key(:incoming_jobs, identifier)
  end

  defp jobs_key(identifier) do
    jobs_key(:jobs, identifier)
  end

  defp failed_jobs_key(identifier) do
    jobs_key(:failed_jobs, identifier)
  end

  defp delayed_jobs_key(identifier) do
    jobs_key(:delayed_jobs, identifier)
  end

  defp redis_query(query) do
    redis() |> Exredis.query(query)
  end

  # This is not a API any production code should rely upon, but could be useful
  # info when debugging or to verify things in tests.
  defp debug_info, do: %{system_pid: System.get_pid(), last_updated_at: system_time()}

  # R17 version of R18's :erlang.system_time
  defp system_time, do: :timer.now_diff(:erlang.now(), {0, 0, 0}) * 1000

  defp alive_key(identifier), do: "#{default_scope()}:#{identifier}:alive"
  defp registered_vms_key, do: "#{default_scope()}:registered_vms"

  defp identifier_scoped_key(key, identifier) do
    prefix = Application.get_env(:toniq, :redis_key_prefix)
    "#{prefix}:#{identifier}:#{key}"
  end

  defp store_job_in_key(job, key, identifier) do
    job_id = redis() |> incr(counter_key())

    job =
      job
      |> Job.set_id(job_id)
      |> Job.add_vm_identifier(identifier)

    redis() |> sadd(key, prepare_for_redis(job))
    job
  end

  defp load_jobs(redis_key, identifier) do
    redis()
    |> smembers(redis_key)
    |> Enum.map(&build_job/1)
    |> Enum.sort(&first_in_first_out/2)
    |> Enum.map(fn job -> convert_to_latest_job_format(job, redis_key) end)
    |> Enum.map(fn job ->
      error = (Map.has_key?(job, :error) && job.error) || nil
      options = (Map.has_key?(job, :options) && job.options) || nil

      %Job{
        id: job.id,
        worker: job.worker,
        arguments: job.arguments,
        version: 1,
        options: options,
        error: error,
        vm: identifier
      }
    end)
  end

  defp build_job(data) do
    :erlang.binary_to_term(data)
  end

  defp prepare_for_redis(job) do
    job
    |> Map.from_struct()
    |> Map.to_list()
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.into(%{})
    |> Map.delete(:vm)
  end

  defp convert_to_latest_job_format(loaded_job, redis_key) do
    case Toniq.Job.migrate(loaded_job) do
      {:unchanged, job} ->
        job

      {:changed, old, new} ->
        redis()
        |> Exredis.query_pipe([
          ["MULTI"],
          ["SREM", redis_key, old],
          ["SADD", redis_key, new],
          ["EXEC"]
        ])

        new
    end
  end

  defp first_in_first_out(first, second) do
    first.id < second.id
  end

  defp counter_key do
    global_key(:last_job_id)
  end

  defp global_key(key) do
    prefix = Application.get_env(:toniq, :redis_key_prefix)
    "#{prefix}:#{key}"
  end

  defp redis do
    Process.whereis(:toniq_redis)
  end

  defp default_identifier, do: Toniq.Keepalive.identifier()
end
