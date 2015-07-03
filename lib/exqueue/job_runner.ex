defmodule Exqueue.JobRunner do
  def register_job(job) do
    spawn_link fn ->
      job
      |> run_job
      |> process_result
    end
  end

  def run_job(job) do
    run_job_in_background(job)

    case wait_for_result do
      :successful ->
        {:mark_as_finished, job}
      :failed ->
        # recurse after waiting to retry here later?
        {:mark_as_failed, job}
    end
  end

  defp process_result({:mark_as_finished, job}) do
    # TODO: make this API take a job
    Exqueue.Peristance.mark_as_finished(job.id)
  end

  defp process_result({:mark_as_failed, job}) do
    Exqueue.Peristance.mark_as_failed(job)
  end

  defp run_job_in_background(job) do
    parent = self

    spawn_monitor fn ->
      try do
        #IO.inspect "Running #{inspect(job)}"
        job.worker.perform(job.opts)
      rescue
        error ->
          send parent, {:failed_because_of_an_error, error}
      end
    end
  end

  defp wait_for_result do
    receive do
      {:DOWN, _ref, :process, _pid, :normal} ->
        :successful
      {:DOWN, _ref, :process, _pid, _error} -> # Failed beause the process crashed
        :failed
      {:failed_because_of_an_error, _error} ->
        :failed
      other ->
        raise "The job running process sent an unknown message: #{other}"
    end
  end
end
