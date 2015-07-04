# Listens for new jobs and sends them to workers.

# TODO: not entierly sure how to test this yet besides the full integration test

defmodule Toniq.JobSubscriber do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(args) do
    start_subscribing_for_jobs
    start_polling_for_jobs
    {:ok, []}
  end

  defp start_subscribing_for_jobs do
    Spawn.spawn_link_with_name :wait_for_new_jobs, fn ->
      Toniq.Peristance.subscribe_to_new_jobs
      wait_for_new_jobs
    end
  end

  defp start_polling_for_jobs do
    Spawn.spawn_link_with_name :poll_for_jobs, &poll_for_jobs/0
  end

  defp wait_for_new_jobs do
    receive do
      :job_added ->
        GenServer.cast(__MODULE__, :job_added)
    end

    wait_for_new_jobs
  end

  def handle_cast(:job_added, state) do
    look_for_new_jobs
    {:noreply, state}
  end

  defp poll_for_jobs do
    look_for_new_jobs
    :timer.sleep(1000)
    poll_for_jobs
  end

  defp look_for_new_jobs do
    # This is slightly inefficient if you get lots of unprocessed jobs queued up,
    # but we'll fix that if it ever becomes an issue, until then we don't need to
    # spend time on any challenges and issues that change would introduce.
    Toniq.Peristance.jobs
    |> Enum.each &Toniq.JobRunner.register_job/1
  end
end
