defmodule Toniq.JobEvent do
  @moduledoc """
  Reports events from the job running lifecycle.
  """

  def start_link do
    {:ok, _pid} = GenEvent.start_link(name: __MODULE__)
  end

  defmodule MessageForwarder do
    use GenEvent

    def handle_event(event, [listener]) do
      send listener, event
      {:ok, [listener]}
    end
  end

  @doc """
  Subscribes the current process to events. Events will be sent by regular messages to the current process.
  """
  def subscribe do
    GenEvent.add_handler(__MODULE__, MessageForwarder, [self])
  end

  @doc """
  Unsubscribes the current process.
  """
  def unsubscribe do
    GenEvent.remove_handler(__MODULE__, MessageForwarder, [self])
  end

  def finished(job) do
    notify {:finished, job}
  end

  def failed(job) do
    notify {:failed, job}
  end

  defp notify(event) do
    :ok = GenEvent.notify(__MODULE__, event)
  end
end
