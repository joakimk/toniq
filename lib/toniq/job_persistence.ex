defmodule Toniq.JobPersistence do
  use Exredis.Api

  @doc """
  Stores a job in redis. If it does not succeed it will fail right away.
  """
  def store_job(worker_module, opts, identifier \\ default_identifier) do
    store_job_in_key(worker_module, opts, jobs_key(identifier))
  end

  # only used in tests
  def store_incoming_job(worker_module, opts, identifier \\ default_identifier) do
    store_job_in_key(worker_module, opts, incoming_jobs_key(identifier))
  end

  @doc """
  Returns all jobs that has not yet finished or failed.
  """
  def jobs(identifier \\ default_identifier), do: load_jobs(jobs_key(identifier))

  @doc """
  Returns all incoming jobs (used for failover).
  """
  def incoming_jobs(identifier \\ default_identifier), do: load_jobs(incoming_jobs_key(identifier))

  @doc """
  Returns all failed jobs.
  """
  def failed_jobs, do: load_jobs(failed_jobs_key)

  @doc """
  Marks a job as finished. This means that it's deleted from redis.
  """
  def mark_as_successful(job, identifier \\ default_identifier) do
    redis
    |> srem(jobs_key(identifier), job)
  end

  @doc """
  Marks a job as failed. This removes the job from the regular list and stores it in the failed jobs list.
  """
  def mark_as_failed(job, identifier \\ default_identifier) do
    redis |> Exredis.query_pipe([
      ["MULTI"],
      ["SREM", jobs_key(identifier), job],
      ["SADD", failed_jobs_key, job],
      ["EXEC"],
    ])
  end

  def jobs_key(identifier) do
    identifier_scoped_key :jobs, identifier
  end

  def incoming_jobs_key(identifier) do
    identifier_scoped_key :incoming_jobs, identifier
  end

  defp store_job_in_key(worker_module, opts, key) do
    job_id = redis |> incr(counter_key)

    job = %{ id: job_id, worker: worker_module, opts: opts }
    redis |> sadd(key, job)
    job
  end

  defp load_jobs(redis_key) do
    redis
    |> smembers(redis_key)
    |> Enum.map &build_job/1
  end

  defp build_job(data) do
    :erlang.binary_to_term(data)
  end

  defp failed_jobs_key do
    identifier_scoped_key :failed_jobs, default_identifier
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
