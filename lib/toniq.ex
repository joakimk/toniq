defmodule Toniq do
  use Application
  require Logger

  @doc """
  Enqueue for use in pipelines

  Example:

    params
    |> extract_data
    |> Toniq.enqueue_to(SendEmailWorker)
  """
  def enqueue_to(opts, worker_module) do
    enqueue(worker_module, opts)
  end

  @doc """
  Enqueue job to be run in the background as soon as possible
  """
  def enqueue(worker_module, opts \\ []) do
    Toniq.JobPersistence.store_job(worker_module, opts)
    |> Toniq.JobRunner.register_job
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Toniq.Config.init

    children = [
      worker(Toniq.RedisConnection, []),
      worker(Toniq.JobRunner, []),
      worker(Toniq.JobEvent, []),
      worker(Toniq.Keepalive, []),
      worker(Toniq.Takeover, []),
      worker(Toniq.JobImporter, []),
    ]

    # When one process fails we restart all of them to ensure a valid state. Jobs are then
    # re-loaded from redis. Supervisor docs: http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    opts = [strategy: :one_for_all, name: Toniq.Supervisor, max_seconds: 15, max_restarts: 3]
    Supervisor.start_link(children, opts)
  end
end
