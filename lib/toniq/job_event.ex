defmodule Toniq.JobEvent do
  use GenServer

  @moduledoc """
  Reports events from the job running lifecycle.
  """

  def start_link do
    {:ok, _pid} = GenServer.start_link(__MODULE__, %{listeners: []}, name: __MODULE__)
  end

  def init(args) do
    {:ok, args}
  end

  @doc """
  Subscribes the current process to events. Events will be sent by regular messages to the current process.
  """
  def subscribe do
    GenServer.call(__MODULE__, :subscribe)
  end

  @doc """
  Unsubscribes the current process.
  """
  def unsubscribe do
    GenServer.call(__MODULE__, :unsubscribe)
  end

  def handle_call(:subscribe, {caller, _ref}, state) do
    state = Map.put(state, :listeners, state.listeners ++ [caller])
    {:reply, :ok, state}
  end

  def handle_call(:unsubscribe, {caller, _ref}, state) do
    state = Map.put(state, :listeners, state.listeners -- [caller])
    {:reply, :ok, state}
  end

  def handle_cast({:notify, event}, state) do
    Enum.each(state.listeners, fn pid ->
      send(pid, event)
    end)

    {:noreply, state}
  end

  def finished(job) do
    notify({:finished, job})
  end

  def failed(job) do
    notify({:failed, job})
  end

  defp notify(event) do
    GenServer.cast(__MODULE__, {:notify, event})
  end
end
