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
    Toniq.Persistence.store_job(worker_module, opts)
    |> Toniq.JobRunner.register_job
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    set_up_redis
    spawn_link fn ->
      :timer.sleep 1000 # wait for things to start
      if Mix.env != :test, do: enqueue_waiting_jobs
    end

    children = [
      worker(Toniq.JobRunner, []),
      worker(Toniq.JobEvent, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Toniq.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Temporary way to restore jobs on app boot, later we want something that ensures
  # that not every VM will try and requeue any waiting jobs. This way, jobs are run,
  # but they might be run more than once.
  defp enqueue_waiting_jobs do
    jobs = Toniq.Persistence.jobs

    if Enum.count(jobs) > 0 do
      Logger.info "Requeuing #{Enum.count(jobs)} jobs from redis on app boot"
    end

    jobs
    |> Enum.each &Toniq.JobRunner.register_job/1
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
