defmodule Toniq do
  use Application

  alias Toniq.Peristance

  def enqueue(worker_module, opts) do
    Peristance.store_job(worker_module, opts)
    Toniq.PubSub.publish
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    set_up_redis

    children = [
      worker(Toniq.JobSubscriber, []),
      worker(Toniq.JobRunner, []),
      worker(Toniq.JobEvent, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Toniq.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp set_up_redis do
    # Not supervising exredis seems like it could work as :eredis reconnects if needed,
    # but will look into this more later.
    #
    # https://github.com/wooga/eredis#reconnecting-on-redis-down--network-failure--timeout--etc
    Application.get_env(:toniq, :redis_url)
    |> Exredis.start_using_connection_string
    |> Process.register(:redis)

    config = Application.get_env(:toniq, :redis_url) |> Exredis.ConnectionString.parse
    { :ok, pid } = :eredis_sub.start_link(String.to_char_list(config.host), config.port, String.to_char_list(config.password))
    Process.register(pid, :subscribe_redis)

    # TODO: do this in a cleaner way, preferabbly after each redis test
    if Mix.env == :test do
      Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])
    end
  end
end
