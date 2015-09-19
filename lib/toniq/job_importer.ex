defmodule Toniq.JobImporter do
  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init(state) do
    {:ok, _} = :timer.send_interval job_import_interval, :import_jobs
    {:ok, state}
  end

  def handle_info(:import_jobs, state) do
    import_jobs(enabled: enabled?)
    {:noreply, state}
  end

  defp import_jobs(enabled: false), do: nil
  defp import_jobs(enabled: true) do
    incoming_jobs
    |> log_import
    |> Enum.each fn(job) ->
      Toniq.enqueue(job.worker, job.opts)
      Toniq.JobPersistence.remove_from_incoming_jobs(job)
    end
  end

  defp log_import([]), do: []
  defp log_import(jobs) do
    if Mix.env != :test do
      Logger.log(:info, "Importing #{Enum.count(jobs)} jobs from incoming_jobs")
    end

    jobs
  end

  defp incoming_jobs do
    Toniq.JobPersistence.incoming_jobs
  end

  defp enabled?, do: !Application.get_env(:toniq, :disable_import)

  defp job_import_interval, do: Application.get_env(:toniq, :job_import_interval)
end

