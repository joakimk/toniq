defmodule Toniq.Peristance do
  use Exredis.Api

  @doc """
  Stores a job in redis. If it does not succeed it will fail right away.
  """
  def store_job(worker_module, opts) do
    job_id = redis |> incr(counter_key)

    redis
    |> hset(jobs_key, job_id, :erlang.term_to_binary(%{ worker: worker_module, opts: opts }))

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
    |> hdel(jobs_key, job.id)
  end

  @doc """
  Marks a job as finished. This means that it's deleted from redis.
  """
  def mark_as_failed(job) do
    job_data = hget(redis, jobs_key, job.id)

    redis |> Exredis.query_pipe([
      ["MULTI"],
      ["HDEL", jobs_key, job.id],
      ["HSET", failed_jobs_key, job.id, job_data],
      ["EXEC"],
    ])
  end

  defp load_jobs(redis_key) do
    redis
    |> hgetall(redis_key)
    |> Enum.map &build_job/1
  end

  defp build_job({key, data}) do
    { job_id, _remainder_of_string } = Integer.parse(key)
    :erlang.binary_to_term(data) |> Dict.put(:id, job_id)
  end

  defp jobs_key do
    :toniq_jobs
  end

  defp failed_jobs_key do
    :toniq_failed_jobs
  end

  defp counter_key do
    :toniq_last_job_id
  end

  defp redis do
    Process.whereis(:redis)
  end
end
