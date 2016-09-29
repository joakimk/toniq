defmodule Toniq.DelayedJobTracker do
  use GenServer

  alias Toniq.JobPersistence

  def start_link(name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def init(state) do
    Process.send_after(self(), :flush, 100)
    {:ok, state}
  end

  def register_job(job) do
    GenServer.cast(__MODULE__, {:register_job, job})
    job
  end

  def handle_call(:ping, _from, jobs) do
    {:reply, jobs, jobs}
  end

  def handle_cast({:register_job, job}, delayed_jobs) do
    {:noreply, [job | delayed_jobs]}
  end

  def handle_info(:flush, delayed_jobs) do
    Process.send_after(self(), :flush, 100)

    delayed_jobs
    |> enqueue_expired_jobs
    |> remaining_jobs_from(delayed_jobs)
  end

  defp enqueue_expired_jobs(jobs) do
    jobs
    |> Stream.filter(&(&1.delayed_until <= :os.system_time(:milli_seconds)))
    |> Enum.map(&(JobPersistence.move_delayed_job_to_incoming_jobs(&1)))
  end

  defp remaining_jobs_from(expired_jobs, all_jobs) do
    remaining_jobs = all_jobs
      |> MapSet.new
      |> MapSet.difference(MapSet.new(expired_jobs))
      |> MapSet.to_list

    {:noreply, remaining_jobs}
  end
end
