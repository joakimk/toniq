defmodule Toniq.JobPersistence do
  import Exredis.Api

  @doc """
  Stores a job in redis. If it does not succeed it will fail right away.
  """
  def store_job(worker_module, arguments, identifier \\ default_identifier()) do
    store_job_in_key(worker_module, arguments, jobs_key(identifier), identifier)
  end

  # Only used in tests
  def store_incoming_job(worker_module, arguments, identifier \\ default_identifier()) do
    store_job_in_key(worker_module, arguments, incoming_jobs_key(identifier), identifier)
  end

  @doc """
  Stores a delayed job in redis.
  """
  def store_delayed_job(worker_module, arguments, options, identifier \\ default_identifier()) do
    store_job_in_key(worker_module, arguments, delayed_jobs_key(identifier), identifier, options)
  end

  # Only used internally by JobImporter
  def remove_from_incoming_jobs(job) do
    redis() |> srem(incoming_jobs_key(default_identifier()), strip_vm_identifier(job))
  end

  @doc """
  Returns all jobs that has not yet finished or failed.
  """
  def jobs(identifier \\ default_identifier()), do: load_jobs(jobs_key(identifier), identifier)

  @doc """
  Returns all incoming jobs (used for failover).
  """
  def incoming_jobs(identifier \\ default_identifier()), do: load_jobs(incoming_jobs_key(identifier), identifier)

  @doc """
  Returns all failed jobs.
  """
  def failed_jobs(identifier \\ default_identifier()), do: load_jobs(failed_jobs_key(identifier), identifier)

  @doc """
  Returns all delayed jobs.
  """
  def delayed_jobs(identifier \\ default_identifier()), do: load_jobs(delayed_jobs_key(identifier), identifier)

  @doc """
  Marks a job as finished. This means that it's deleted from redis.
  """
  def mark_as_successful(job, identifier \\ default_identifier()) do
    redis()
    |> srem(jobs_key(identifier), strip_vm_identifier(job))
  end

  @doc """
  Marks a job as failed. This removes the job from the regular list and stores it in the failed jobs list.
  """
  def mark_as_failed(job, error, identifier \\ default_identifier()) do
    job_with_error = Map.put(job, :error, error)

    redis() |> Exredis.query_pipe([
      ["MULTI"],
      ["SREM", jobs_key(identifier), strip_vm_identifier(job)],
      ["SADD", failed_jobs_key(identifier), strip_vm_identifier(job_with_error)],
      ["EXEC"],
    ])

    job_with_error
  end

  @doc """
  Moves a failed job to the regular jobs list.

  Uses "job.vm" to do the operation in the correct namespace.
  """
  def move_failed_job_to_incomming_jobs(job_with_error) do
    job = Map.delete(job_with_error, :error)

    redis() |> Exredis.query_pipe([
      ["MULTI"],
      ["SREM", failed_jobs_key(job.vm), strip_vm_identifier(job_with_error)],
      ["SADD", incoming_jobs_key(job.vm), strip_vm_identifier(job)],
      ["EXEC"],
    ])

    job
  end

  @doc """
  Moves a delayed job to the regular jobs list.

  Uses "job.vm" to do the operation in the correct namespace.
  """
  def move_delayed_job_to_incoming_jobs(delayed_job) do
    redis() |> Exredis.query_pipe([
      ["MULTI"],
      ["SREM", delayed_jobs_key(delayed_job.vm), strip_vm_identifier(delayed_job)],
      ["SADD", incoming_jobs_key(delayed_job.vm), strip_vm_identifier(delayed_job)],
      ["EXEC"],
    ])
    delayed_job
  end

  @doc """
  Deletes a failed job.

  Uses "job.vm" to do the operation in the correct namespace.
  """
  def delete_failed_job(job) do
    redis()
    |> srem(failed_jobs_key(job.vm), strip_vm_identifier(job))
  end

  def jobs_key(identifier) do
    identifier_scoped_key :jobs, identifier
  end

  def failed_jobs_key(identifier) do
    identifier_scoped_key :failed_jobs, identifier
  end

  def delayed_jobs_key(identifier) do
    identifier_scoped_key :delayed_jobs, identifier
  end

  def incoming_jobs_key(identifier) do
    identifier_scoped_key :incoming_jobs, identifier
  end

  defp store_job_in_key(worker_module, arguments, key, identifier, options \\ []) do
    job_id = redis() |> incr(counter_key())

    job = Toniq.Job.build(job_id, worker_module, arguments, options) |> add_vm_identifier(identifier)
    redis() |> sadd(key, strip_vm_identifier(job))
    job
  end

  defp load_jobs(redis_key, identifier) do
    redis()
    |> smembers(redis_key)
    |> Enum.map(&build_job/1)
    |> Enum.sort(&first_in_first_out/2)
    |> Enum.map(fn (job) -> convert_to_latest_job_format(job, redis_key) end)
    |> Enum.map(fn (job) -> add_vm_identifier(job, identifier) end)
  end

  defp build_job(data) do
    :erlang.binary_to_term(data)
  end

  def add_vm_identifier(job, identifier), do: job |> Map.put(:vm, identifier)
  def strip_vm_identifier(job),           do: job |> Map.delete(:vm)

  defp convert_to_latest_job_format(loaded_job, redis_key) do
    case Toniq.Job.migrate(loaded_job) do
      {:unchanged, job} ->
        job
      {:changed, old, new} ->
        redis() |> Exredis.query_pipe([
          ["MULTI"],
          ["SREM", redis_key, old],
          ["SADD", redis_key, new],
          ["EXEC"],
        ])

        new
    end
  end

  defp first_in_first_out(first, second) do
    first.id < second.id
  end

  defp counter_key do
    global_key :last_job_id
  end

  defp global_key(key) do
    prefix = Application.get_env(:toniq, :redis_key_prefix)
    "#{prefix}:#{key}"
  end

  defp identifier_scoped_key(key, identifier) do
    prefix = Application.get_env(:toniq, :redis_key_prefix)
    "#{prefix}:#{identifier}:#{key}"
  end

  defp redis do
    Process.whereis(:toniq_redis)
  end

  defp default_identifier, do: Toniq.Keepalive.identifier
end
