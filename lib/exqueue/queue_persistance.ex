defmodule Exqueue.QueuePeristance do
  use Exredis.Api

  @doc """
  Stores a job in redis. If it does not succeed it will fail right away.
  """
  def enqueue(worker_module, opts) do
    job_id = redis |> incr(:last_job_id)

    redis
    |> hset(:jobs, job_id, :erlang.term_to_binary(%{ worker: worker_module, opts: opts }))
  end

  @doc """
  Returns all jobs that has not yet finished or failed.
  """
  def jobs do
    redis
    |> hgetall(:jobs)
    |> Enum.map fn({ key, data }) ->
      { job_id, _remainder_of_string } = Integer.parse(key)
      :erlang.binary_to_term(data)
      |> Dict.put(:id, job_id)
    end
  end

  @doc """
  Marks a job as finished. This means that it's deleted from redis.
  """
  def mark_as_finished(job_id) do
    redis
    |> hdel(:jobs, job_id)
  end

  defp redis do
    Process.whereis(:redis)
  end
end
