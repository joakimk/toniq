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

    Toniq.Config.setup

    set_up_redis

    children = [
      worker(Toniq.JobRunner, []),
      worker(Toniq.JobEvent, []),
      worker(Toniq.Keepalive, []),
      worker(Toniq.Takeover, []),
      worker(Toniq.JobImporter, []),
    ]

    # When one process fails we restart all of them to ensure a valid state. Jobs are then
    # re-loaded from redis. Supervisor docs: http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    opts = [strategy: :one_for_all, name: Toniq.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp set_up_redis do
    # Not supervising exredis seems like it could work as :eredis reconnects if needed,
    # but will look into this more later.
    #
    # https://github.com/wooga/eredis#reconnecting-on-redis-down--network-failure--timeout--etc
    redis_url
    |> Exredis.start_using_connection_string
    |> register_redis
  end

  defp register_redis({:connection_error, error}) do
    raise """


    Could not connect to redis.

    The error was: "#{inspect(error)}"

    Some things you could check:
    * Is the redis server running?

    * Did you set Mix.Config in your app?
      Example:
      config :toniq, redis_url: "redis://localhost:6379/0"

    * Is the current redis_url (#{redis_url}) correct?
    """
  end

  defp register_redis(pid) do
    pid
    |> Process.register(:toniq_redis)
  end

  defp redis_url do
    Application.get_env(:toniq, :redis_url)
  end
end
