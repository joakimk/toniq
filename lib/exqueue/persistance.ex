defmodule Exqueue.Peristance do
  use Exredis.Api

  @doc """
  Stores a job in redis. If it does not succeed it will fail right away.
  """
  def store_job(worker_module, opts) do
    job_id = redis |> incr(:last_job_id)

    redis
    |> hset(jobs_key, job_id, :erlang.term_to_binary(%{ worker: worker_module, opts: opts }))

    Exqueue.PubSub.publish
  end

  @doc """
  Returns all jobs that has not yet finished or failed.
  """
  def jobs do
    redis
    |> hgetall(jobs_key)
    |> Enum.map fn({ key, data }) ->
      { job_id, _remainder_of_string } = Integer.parse(key)
      :erlang.binary_to_term(data)
      |> Dict.put(:id, job_id)
    end
  end

  @doc """
  Marks a job as finished. This means that it's deleted from redis.
  """
  def mark_as_finished(job) do
    redis
    |> hdel(jobs_key, job.id)
  end

  @doc """
  Marks a job as finished. This means that it's deleted from redis.
  """
  def mark_as_failed(job) do
    #redis
    #|> hdel(jobs_key, job.id)
  end

  @doc """
  Subscribes to added jobs. The current process will receive :job_added when a job is added.
  """
  def subscribe_to_new_jobs do
    Exqueue.PubSub.subscribe
  end

  defp jobs_key do
    "exqueue_jobs"
  end

  defp redis do
    Process.whereis(:redis)
  end
end
