defmodule Exqueue.JobProcess do
  def run(job) do
    run_job_in_background(job)

    case wait_for_result do
      :ok ->
        {:job_was_successful, job}
      error ->
        # recurse after waiting to retry here later?
        {:job_has_failed, job, error}
    end
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
        |> wrap_in_crash_error
      {:failed_because_of_an_error, error} ->
        error
      {:"$gen_cast", _} -> # Don't listen to GenServer events here
        wait_for_result
      other ->
        raise "The job running process sent an unknown message: #{inspect(other)}"
    end
  end

  defmodule CrashError do
    @moduledoc """
      Represents a process crash. Ensures we always return an error struct,
      even if the crash didn't occur from a raised error.

      Keeps the consuming code simple.
    """

    defstruct message: ""
  end

  defp wrap_in_crash_error(message) do
    %CrashError{message: message}
  end
end
