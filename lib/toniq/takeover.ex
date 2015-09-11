# WIP: Not fully used within the app yet

defmodule Toniq.Takeover do
  use GenServer

  def start_link(system_pid \\ System.get_pid) do
    uuid = UUID.uuid1()
    GenServer.start_link(__MODULE__, %{ uuid: uuid }, name: process_name(system_pid))
  end

  def uuid(system_pid \\ System.get_pid) do
    GenServer.call(process_name(system_pid), :uuid)
  end

  def handle_call(:uuid, _from, state) do
    { :reply, state.uuid, state }
  end

  defp process_name(system_pid) do
    String.to_atom("#{__MODULE__}:#{system_pid}")
  end
end
