defmodule Toniq.RedisConnection do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(state) do
    # TODO: Replace this very basic timeout between attempts
    :timer.sleep 250

    # Not supervising exredis seems like it could work as :eredis reconnects if needed,
    # but will look into this more later.
    #
    # https://github.com/wooga/eredis#reconnecting-on-redis-down--network-failure--timeout--etc
    redis_url
    |> Exredis.start_using_connection_string
    |> register_redis

    {:ok, state}
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
