defmodule Exqueue do
  use Application

  alias Exqueue.QueuePeristance

  def start_worker(worker_module) do
    # start manager process and attach that to a supervisor
    # Worker.add(worker_module)
    #WorkerWatcher
    #Worker
  end

  def enqueue(worker_module, opts) do
    QueuePeristance.enqueue(worker_module, opts)
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Application.get_env(:exqueue, :redis_url)
    |> Exredis.start_using_connection_string
    |> Process.register(:redis)

    # TODO: do this in a cleaner way, preferabbly after each redis test
    if Mix.env == :test do
      Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])
    end

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Exqueue.Worker, [arg1, arg2, arg3])
      #worker(Queue, [[name: :queue]])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Exqueue.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
