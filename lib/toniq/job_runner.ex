defmodule Toniq.JobRunner do
  use GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(args) do
    {:ok, args}
  end

  def register_job(job) do
    GenServer.cast(__MODULE__, {:register_job, job})
    job
  end

  def handle_cast({:register_job, job}, state) do
    spawn_link(fn ->
      job
      |> run_job
      |> retry_when_failing
      |> process_result
    end)

    {:noreply, state}
  end

  defp run_job(job), do: Toniq.JobConcurrencyLimiter.run(job)

  defp retry_when_failing(status), do: retry_when_failing(status, 1)
  defp retry_when_failing({:job_was_successful, job}, _attempt), do: {:job_was_successful, job}

  defp retry_when_failing({:job_has_failed, job, error, stack}, attempt) do
    if retry_strategy().retry?(attempt) do
      :timer.sleep(trunc(retry_strategy().ms_to_sleep_before(attempt)))

      result = run_job(job)
      retry_when_failing(result, attempt + 1)
    else
      {:job_has_failed, job, error, stack}
    end
  end

  defp process_result({:job_was_successful, job}) do
    Toniq.JobPersistence.adapter().mark_as_successful(job)
    Toniq.JobEvent.finished(job)
  end

  defp process_result({:job_has_failed, job, error, stack}) do
    Toniq.JobPersistence.adapter().mark_as_failed(job, error)
    log_error(job, error, stack)
    Toniq.JobEvent.failed(job)
  end

  defp retry_strategy, do: Application.get_env(:toniq, :retry_strategy)

  defp log_error(job, error, stack) do
    stacktrace = Exception.format_stacktrace(stack)
    job_details = "##{job.id}: #{inspect(job.worker)}.perform(#{inspect(job.arguments)})"

    "Job #{job_details} failed with error: #{inspect(error)}\n\n#{stacktrace}"
    |> String.trim()
    |> Logger.error()
  end
end
