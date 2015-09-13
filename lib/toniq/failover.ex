# WIP: Not fully used within the app yet

defmodule Toniq.Failover do
  use GenServer

  def start_link do
    uuid = UUID.uuid1()
    GenServer.start_link(__MODULE__, %{ uuid: uuid }, name: __MODULE__)
  end

  def uuid do
    GenServer.call(__MODULE__, :uuid)
  end

  def handle_call(:uuid, _from, state) do
    {:reply, state.uuid, state}
  end
end
