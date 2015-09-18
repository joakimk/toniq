defmodule Toniq.JobImporter do
  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init(state) do
    :timer.send_interval job_import_interval, :import_jobs
    {:ok, state}
  end

  def handle_info(:import_jobs, state) do
    incoming_jobs
    |> Enum.each fn(job) ->
      Toniq.enqueue(job.worker, job.opts)
      Toniq.JobPersistence.remove_from_incoming_jobs(job)
    end

    {:noreply, state}
  end

  defp incoming_jobs do
    Toniq.JobPersistence.incoming_jobs
  end

  defp job_import_interval, do: Application.get_env(:toniq, :job_import_interval)
end

