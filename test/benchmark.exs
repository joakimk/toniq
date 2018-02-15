# Benchmark
# MIX_ENV=prod mix compile
# MIX_ENV=prod mix run test/benchmark.exs

job_count = 10000

# Wait for takeover to run
:timer.sleep(5000)
IO.puts("")

defmodule BenchWorker do
  use Toniq.Worker

  def perform do
  end
end

defmodule JobFinishedCounter do
  def count(number, total) when number == total do
    # done
  end

  def count(number, total) do
    receive do
      {:finished, _job} ->
        nil
    end

    count(number + 1, total)
  end
end

defmodule Measure do
  def duration(job_count, function) do
    start_time = :os.system_time()
    function.()
    ms = (:os.system_time() - start_time) / 1_000_000
    ms_per_job = ms / job_count
    jobs_per_second = :erlang.round(1000 / ms_per_job)
    IO.puts("#{ms} ms in total, #{ms_per_job} ms/job #{jobs_per_second} jobs/second")
  end
end

Toniq.JobEvent.subscribe()

IO.puts("Benchmark: #{job_count} messages sent to self (benchmark overhead)")

Measure.duration(job_count, fn ->
  1..job_count
  |> Enum.each(fn _ ->
    send(self, {:finished, :foo})
  end)

  JobFinishedCounter.count(0, job_count)
end)

IO.puts("")
IO.puts("Benchmark: #{job_count} persisted jobs")

Measure.duration(job_count, fn ->
  1..job_count
  |> Enum.each(fn _ ->
    Toniq.enqueue(BenchWorker)
  end)

  JobFinishedCounter.count(0, job_count)
end)
