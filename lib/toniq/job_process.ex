defmodule Toniq.JobProcess do
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
      result =
        try do
          #IO.inspect "Running #{inspect(job)}"
          job.worker.perform(job.opts)
          :success
        rescue
          error ->
            {:failed_because_of_an_error, error}
        end

      send parent, result
    end
  end

  defp wait_for_result do
    receive do
      {:DOWN, _ref, :process, _pid, :normal} ->
        # both errors and successes result in a normal exit, wait for more information
        wait_for_result
      {:DOWN, _ref, :process, _pid, error} -> # Failed beause the process crashed
        "The job runner crashed. The reason that was given is: #{error}"
        |> wrap_in_crash_error
      {:failed_because_of_an_error, error} ->
        error
      :success ->
        :ok
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
