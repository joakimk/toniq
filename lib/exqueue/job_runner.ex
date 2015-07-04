defmodule Exqueue.JobRunner do
  use GenServer

  defmodule ProcessCrashError do
    @moduledoc """
      Represents a process crash. Ensures we always return an error struct,
      even if the crash didn't occur from a raised error.

      Keeps the consuming code simple.
    """

    defstruct message: ""
  end

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
      :ok ->
        {:job_was_successful, job}
      error ->
        # recurse after waiting to retry here later?
        {:job_has_failed, job, error}
    end
  end

  defp process_result({:job_was_successful, job}) do
    Exqueue.Peristance.mark_as_successful(job)
  end

  defp process_result({:job_has_failed, job, error}) do
    Exqueue.Peristance.mark_as_failed(job)
    IO.inspect "TODO: Report error: #{inspect(error)} for job #{inspect(job)}"
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
        :ok
      {:DOWN, _ref, :process, _pid, error} -> # Failed beause the process crashed
        "The job runner crashed. The reason that was given is: #{error}"
        |> wrap_in_process_crash_error
      {:failed_because_of_an_error, error} ->
        error
      {:"$gen_cast", _} -> # Don't listen to GenServer events here
        wait_for_result
      other ->
        raise "The job running process sent an unknown message: #{inspect(other)}"
    end
  end

  defp wrap_in_process_crash_error(message) do
    %ProcessCrashError{message: message}
  end
end
