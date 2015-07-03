defmodule Exqueue.JobRunner do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: :job_runner)
  end

  def register_job(job) do
    Process.whereis(:job_runner)
    |> GenServer.cast({:register_job, job})
  end

  def handle_cast({:register_job, job}, state) do
    # NOTE: Run jobs concurrently later
    #spawn_link fn ->
      job
      |> run_job
      |> process_result
    #end

    {:noreply, state}
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
    Exqueue.Peristance.mark_as_finished(job)
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
      {:"$gen_cast", _} -> # Don't listen to GenServer events here
        wait_for_result
      other ->
        raise "The job running process sent an unknown message: #{inspect(other)}"
    end
  end
end
