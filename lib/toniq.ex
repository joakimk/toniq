defmodule Toniq do
  use Application

  @doc """
  Enqueue for use in pipelines

  Example:

    params
    |> extract_data
    |> Toniq.enqueue_to(SendEmailWorker)
  """
  def enqueue_to(arguments, worker_module), do: enqueue(worker_module, arguments)

  @doc """
  Enqueue job to be run in the background as soon as possible
  """
  def enqueue(worker_module, arguments \\ []) do
    Toniq.JobPersistence.store_job(worker_module, arguments)
    |> Toniq.JobRunner.register_job
  end

  @doc """
  Stores job in the delayed queue.
  """
  def delay_to(arguments, worker_module) do
    worker_module
    |> Toniq.JobPersistence.store_delayed_job(arguments)
  end

  @doc """
  List failed jobs
  """
  def failed_jobs do
    Toniq.KeepalivePersistence.registered_vms
    |> Enum.flat_map(&Toniq.JobPersistence.failed_jobs/1)
  end

  @doc """
  Retry a failed job
  """
  def retry(job), do: Toniq.JobPersistence.move_failed_job_to_incomming_jobs(job)

  @doc """
  Delete a failed job
  """
  def delete(job), do: Toniq.JobPersistence.delete_failed_job(job)

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Toniq.Config.init

    children = [
      worker(Toniq.RedisConnection, []),
      worker(Toniq.JobRunner, []),
      worker(Toniq.JobEvent, []),
      worker(Toniq.JobConcurrencyLimiter, []),
      worker(Toniq.Keepalive, []),
      worker(Toniq.Takeover, []),
      worker(Toniq.JobImporter, []),
    ]

    # When one process fails we restart all of them to ensure a valid state. Jobs are then
    # re-loaded from redis. Supervisor docs: http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    opts = [
      strategy: :one_for_all,
      name: Toniq.Supervisor,
      max_seconds: 15,
      max_restarts: 3
    ]
    Supervisor.start_link(children, opts)
  end
end
