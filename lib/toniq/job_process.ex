defmodule Toniq.JobProcess do
  def run(job) do
    case run_job(job) do
      :ok ->
        {:job_was_successful, job}
      {error, stack} ->
        {:job_has_failed, job, error, stack}
    end
  end

  defp run_job(job) do
    parent = self()

    spawn_monitor fn ->
      send parent, run_job_and_capture_result(job)
    end

    wait_for_result()
  end

  defp run_job_and_capture_result(job) do
    #IO.inspect "Running #{inspect(job)}"

    try do
      job.worker.perform(job.arguments)
      :success
    rescue
      error ->
        {:failed_because_of_an_error, error, System.stacktrace}
    end
  end

  defp wait_for_result do
    receive do
      {:DOWN, _ref, :process, _pid, :normal} ->
        # both errors and successes result in a normal exit, wait for more information
        wait_for_result()
      {:DOWN, _ref, :process, _pid, error} -> # Failed beause the process crashed
        crash_error =
          "The job runner crashed. The reason that was given is: #{error}"
          |> wrap_in_crash_error

        {crash_error, []}
      {:failed_because_of_an_error, error, stack} ->
        {error, stack}
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
