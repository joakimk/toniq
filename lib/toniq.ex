defmodule Toniq do
  use Application
  require Logger

  def enqueue(worker_module, opts) do
    Toniq.Peristance.store_job(worker_module, opts)
    |> Toniq.JobRunner.register_job
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    set_up_redis
    spawn_link fn ->
      :timer.sleep 1000 # wait for things to start
      enqueue_waiting_jobs
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
    jobs = Toniq.Peristance.jobs

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
    Application.get_env(:toniq, :redis_url)
    |> Exredis.start_using_connection_string
    |> Process.register(:redis)

    # TODO: do this in a cleaner way, preferabbly after each redis test
    if Mix.env == :test do
      Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])
    end
  end
end
