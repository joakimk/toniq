defmodule Toniq.JobPersistence do
  use Exredis.Api

  @doc """
  Stores a job in redis. If it does not succeed it will fail right away.
  """
  def store_job(worker_module, opts) do
    job_id = redis |> incr(counter_key)

    redis
    |> sadd(jobs_key, :erlang.term_to_binary(%{ id: job_id, worker: worker_module, opts: opts }))

    %{ id: job_id, worker: worker_module, opts: opts }
  end

  @doc """
  Returns all jobs that has not yet finished or failed.
  """
  def jobs, do: load_jobs(jobs_key)

  @doc """
  Returns all failed jobs.
  """
  def failed_jobs, do: load_jobs(failed_jobs_key)

  @doc """
  Marks a job as finished. This means that it's deleted from redis.
  """
  def mark_as_successful(job) do
    redis
    |> srem(jobs_key, job)
  end

  @doc """
  Marks a job as failed. This removes the job from the regular list and stores it in the failed jobs list.
  """
  def mark_as_failed(job) do
    redis |> Exredis.query_pipe([
      ["MULTI"],
      ["SREM", jobs_key, job],
      ["SADD", failed_jobs_key, job],
      ["EXEC"],
    ])
  end

  defp load_jobs(redis_key) do
    redis
    |> smembers(redis_key)
    |> Enum.map &build_job/1
  end

  defp build_job(data) do
    :erlang.binary_to_term(data)
  end

  defp jobs_key do
    scoped_key :toniq_jobs
  end

  defp failed_jobs_key do
    scoped_key :toniq_failed_jobs
  end

  defp counter_key do
    scoped_key :toniq_last_job_id
  end

  defp scoped_key(key) do
    prefix = Application.get_env(:toniq, :redis_key_prefix)
    "#{prefix}:#{key}"
  end

  defp redis do
    Process.whereis(:toniq_redis)
  end
end
