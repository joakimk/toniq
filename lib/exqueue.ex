defmodule Exqueue do
  use Application

  alias Exqueue.Peristance

  def start_worker(worker_module) do
    # start manager process and attach that to a supervisor
    # Worker.add(worker_module)
    #WorkerWatcher
    #Worker
  end

  def enqueue(worker_module, opts) do
    Peristance.store_job(worker_module, opts)
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Not supervising exredis seems like it could work as :eredis reconnects if needed,
    # but will look into this more later.
    #
    # https://github.com/wooga/eredis#reconnecting-on-redis-down--network-failure--timeout--etc
    Application.get_env(:exqueue, :redis_url)
    |> Exredis.start_using_connection_string
    |> Process.register(:redis)

    config = Application.get_env(:exqueue, :redis_url) |> Exredis.ConnectionString.parse
    { :ok, pid } = :eredis_sub.start_link(String.to_char_list(config.host), config.port, String.to_char_list(config.password))
    Process.register(pid, :subscribe_redis)

    # TODO: do this in a cleaner way, preferabbly after each redis test
    if Mix.env == :test do
      Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])
    end

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Exqueue.Worker, [arg1, arg2, arg3])
      worker(Exqueue.JobSubscriber, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Exqueue.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
