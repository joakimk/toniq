defmodule Toniq do
  use Application

  @doc """
  Enqueue for use in pipelines

  Example:

    params
    |> extract_data
    |> Toniq.enqueue_to(SendEmailWorker)
  """
  def enqueue_to(arguments, worker_module, options \\ []) do
    options
    |> Keyword.get(:delay_for)
    |> case do
      nil -> enqueue(worker_module, arguments)
      _ -> enqueue_with_delay(worker_module, arguments, options)
    end
  end

  @doc """
  Enqueue job to be run in the background as soon as possible
  """
  def enqueue(worker_module, arguments \\ []) do
    worker_module
    |> Toniq.Job.new(arguments)
    |> Toniq.JobPersistence.adapter().store(:jobs)
    |> Toniq.JobRunner.register_job()
  end

  @doc """
  Enqueue job to be run in the background at a later time
  """
  def enqueue_with_delay(worker_module, arguments, options) do
    worker_module
    |> Toniq.Job.new(arguments, options)
    |> Toniq.JobPersistence.adapter().store(:delayed_jobs)
    |> Toniq.DelayedJobTracker.register_job()
  end

  @doc """
  List failed jobs
  """
  def failed_jobs do
    Toniq.JobPersistence.adapter().registered_vms()
    |> Enum.flat_map(&Toniq.JobPersistence.adapter().fetch(:failed_jobs, &1))
  end

  @doc """
  Retry a failed job
  """
  def retry(job), do: Toniq.JobPersistence.adapter().move_failed_job_to_incoming_jobs(job)

  @doc """
  Delete a failed job
  """
  def delete(job), do: Toniq.JobPersistence.adapter().delete_failed_job(job)

  @doc """
  Flush all delayed jobs
  """
  def flush_delayed_jobs, do: Toniq.DelayedJobTracker.flush_all_jobs()

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Toniq.Config.init()

    children = [
      worker(Toniq.JobRunner, []),
      worker(Toniq.JobEvent, []),
      worker(Toniq.JobConcurrencyLimiter, []),
      worker(Toniq.Keepalive, []),
      worker(Toniq.Takeover, []),
      worker(Toniq.JobImporter, []),
      worker(Toniq.DelayedJobTracker, [])
    ]

    if Application.get_env(:toniq, :persistence) == Toniq.RedisJobPersistence do
      children =
        [
          worker(Toniq.RedisConnection, [])
        ] ++ children
    end

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
