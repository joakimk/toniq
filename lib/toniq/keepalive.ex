# Responsible for ensuring the process is connected to the redis server. If
# the connection fails, this will crash and the supervisor will restart toniq.

# Each time this starts it generates a new identifier used to scope job persistence.

# Toniq.Failover is responsible for reacquiring jobs from crashed/stopped toniq's.

defmodule Toniq.Keepalive do
  use GenServer

  def start_link do
    uuid = UUID.uuid1()
    GenServer.start_link(__MODULE__, %{ uuid: uuid }, name: __MODULE__)
  end

  def identifier do
    GenServer.call(__MODULE__, :uuid)
  end

  def handle_call(:uuid, _from, state) do
    {:reply, state.uuid, state}
  end
end
