# Responsible for ensuring the process is connected to the redis server. If
# the connection fails, this will crash and the supervisor will restart toniq.

# Each time this starts it generates a new identifier used to scope job persistence.

# Other processes handles re-queuing of jobs.

defmodule Toniq.Keepalive do
  use GenServer

  def start_link(scope \\ :toniq, name \\ __MODULE__) do
    identifier = UUID.uuid1()
    GenServer.start_link(__MODULE__, %{ identifier: identifier, scope: scope, starter: self }, name: name)
  end

  def identifier(name \\ __MODULE__) do
    GenServer.call(name, :identifier)
  end

  # private

  def init(state) do
    send self, :register_vm
    {:ok, state}
  end

  def handle_call(:identifier, _from, state) do
    {:reply, state.identifier, state}
  end

  def handle_info(:register_vm, state) do
    register_vm(state)

    update_alive_key(state)
    :timer.send_interval keepalive_interval, :update_alive_key

    {:noreply, state}
  end

  def handle_info(:update_alive_key, state) do
    update_alive_key(state)

    {:noreply, state}
  end

  defp register_vm(state) do
    redis_query(["SADD", registered_vms_key(state.scope), state.identifier])
  end

  defp update_alive_key(state) do
    # Logger.log(:debug, "Updating keepalive for #{state.identifier} #{inspect(debug_info)}")
    redis_query(["PSETEX", alive_key(state), keepalive_expiration, debug_info])
  end

  defp redis_query(query) do
    :toniq_redis
    |> Process.whereis
    |> Exredis.query(query)
  end

  defp alive_key(state),          do: "#{state.scope}:alive_vms:#{state.identifier}"
  defp registered_vms_key(scope), do: "#{scope}:registered_vms"

  defp keepalive_interval,   do: Application.get_env(:toniq, :keepalive_interval)
  defp keepalive_expiration, do: Application.get_env(:toniq, :keepalive_expiration)

  defp debug_info, do: %{ system_pid: System.get_pid, last_updated_at: :os.system_time }
end
