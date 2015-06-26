defmodule Exqueue do
  use Application

  alias Exqueue.Queue

  def add_worker(worker_module) do
    # start manager process and attach that to a supervisor
    # Worker.add(worker_module)
  end

  def enqueue(worker_module, opts) do
    Queue.register_job(worker_module, opts)
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Exqueue.Worker, [arg1, arg2, arg3])
      worker(Queue, [[name: :queue]])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Exqueue.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
