defmodule Toniq.RedisConnection do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(state) do
    Process.flag(:trap_exit, true)

    redis_url()
    |> Exredis.start_using_connection_string
    |> register_redis

    Process.flag(:trap_exit, false)

    {:ok, state}
  end

  defp register_redis({:connection_error, error}) do
    raise """
    \n
    ----------------------------------------------------

    Could not connect to redis.

    The error was: "#{inspect(error)}"

    Some things you could check:

    * Is the redis server running?

    * Did you set Mix.Config in your app?
      Example:
      config :toniq, redis_url: "redis://localhost:6379/0"

    * Is the current redis_url() (#{redis_url()}) correct?

    ----------------------------------------------------

    """
  end

  defp register_redis(pid) do
    pid
    |> Process.register(:toniq_redis)
  end

  defp redis_url do
    redis_url_provider = Application.get_env(:toniq, :redis_url_provider)

    if redis_url_provider do
      redis_url_provider.()
    else
      Application.get_env(:toniq, :redis_url)
    end
  end
end
