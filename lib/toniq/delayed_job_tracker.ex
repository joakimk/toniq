defmodule Toniq.DelayedJobTracker do
  use GenServer

  alias Toniq.JobPersistence

  def start_link(name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, JobPersistence.adapter().fetch(:delayed_jobs), name: name)
  end

  def init(state) do
    schedule_work()
    {:ok, state}
  end

  def register_job(job) do
    GenServer.cast(__MODULE__, {:register_job, job})
    job
  end

  def flush_all_jobs do
    GenServer.cast(__MODULE__, {:flush_all_jobs})
  end

  def reload_job_list do
    GenServer.cast(__MODULE__, :reload_job_list)
  end

  def handle_call(:ping, _from, jobs) do
    {:reply, jobs, jobs}
  end

  def handle_cast(:reload_job_list, _delayed_jobs) do
    {:noreply, JobPersistence.adapter().fetch(:delayed_jobs)}
  end

  def handle_cast({:register_job, job}, delayed_jobs) do
    {:noreply, [job | delayed_jobs]}
  end

  def handle_cast({:flush_all_jobs}, delayed_jobs) do
    delayed_jobs
    |> Enum.each(fn job -> JobPersistence.adapter().move_delayed_job_to_incoming_jobs(job) end)

    {:noreply, []}
  end

  def handle_info(:flush, delayed_jobs) do
    schedule_work()

    delayed_jobs
    |> enqueue_expired_jobs
    |> remaining_jobs_from(delayed_jobs)
  end

  defp schedule_work do
    self()
    |> Process.send_after(:flush, delay_flush_interval())
  end

  defp delay_flush_interval, do: Application.get_env(:toniq, :delay_flush_interval)

  defp enqueue_expired_jobs(jobs) do
    jobs
    |> Stream.filter(&has_expired?/1)
    |> Enum.map(fn job -> JobPersistence.adapter().move_delayed_job_to_incoming_jobs(job) end)
  end

  defp remaining_jobs_from(expired_jobs, all_jobs) do
    remaining_jobs = all_jobs -- expired_jobs
    {:noreply, remaining_jobs}
  end

  defp has_expired?(%{options: nil}), do: true

  defp has_expired?(job) do
    delayed_until = Keyword.get(job.options, :delayed_until)

    delayed_until != nil and delayed_until != :infinity and
      delayed_until <= :os.system_time(:milli_seconds)
  end
end
