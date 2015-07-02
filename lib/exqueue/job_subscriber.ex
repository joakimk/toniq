# Listens for new jobs and sends them to workers.

# TODO: not entierly sure how to test this yet besides the full integration test

defmodule Exqueue.JobSubscriber do
  use GenServer

  def start_link do
    :gen_server.start_link(__MODULE__, :ok, [])
  end

  def init(args) do
    subscribe_to_new_jobs
    start_polling_for_jobs
    {:ok, self}
  end

  defp subscribe_to_new_jobs do
    Exqueue.Peristance.subscribe_to_new_jobs

    # TODO: handle incomming messages somehow, maybe spawn_link,
    # receive the messages, pass them on using genserver calls?
  end

  defp start_polling_for_jobs do
  end
end
