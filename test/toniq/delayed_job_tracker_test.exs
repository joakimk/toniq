defmodule Toniq.DelayedJobTrackerTest do
  use ExUnit.Case
  use Retry

  alias Toniq.{DelayedJobTracker, JobPersistence}

  defmodule TestWorker do
    use Toniq.Worker

    def perform(_) do
    end
  end

  setup do
    Process.whereis(:toniq_redis) |> Exredis.query([ "FLUSHDB" ])
    :ok
  end

  test "imports delayed jobs on start" do
    TestWorker
    |> JobPersistence.store_delayed_job(%{some: "data"}, delay_for: 250)

    TestWorker
    |> JobPersistence.store_delayed_job(%{some: "data"}, delay_for: 500)

    assert JobPersistence.delayed_jobs |> Enum.count == 2

    DelayedJobTracker.start_link(:test_delayed_job_tracker)

    assert (wait with: lin_backoff(100, 1) |> expiry(1_000) do
      JobPersistence.delayed_jobs |> Enum.empty?
    end)
  end

  test "can register and flush delayed jobs" do
    DelayedJobTracker.start_link(:test_delayed_job_tracker)

    TestWorker
    |> JobPersistence.store_delayed_job(%{some: "data"}, delay_for: 250)
    |> DelayedJobTracker.register_job

    TestWorker
    |> JobPersistence.store_delayed_job(%{some: "data"}, delay_for: 500)
    |> DelayedJobTracker.register_job

    assert JobPersistence.delayed_jobs |> Enum.count == 2
    assert (wait with: lin_backoff(100, 1) |> expiry(1_000) do
      JobPersistence.delayed_jobs |> Enum.empty?
    end)
  end

  test "doesn't flush jobs that are delayed indefinitely" do
    DelayedJobTracker.start_link(:test_delayed_job_tracker)

    TestWorker
    |> JobPersistence.store_delayed_job(%{some: "data"}, delay_for: :infinity)
    |> DelayedJobTracker.register_job

    TestWorker
    |> JobPersistence.store_delayed_job(%{some: "data"}, delay_for: :infinity)
    |> DelayedJobTracker.register_job

    assert JobPersistence.delayed_jobs |> Enum.count == 2

    :timer.sleep(1_000)

    assert JobPersistence.delayed_jobs |> Enum.count == 2
  end

  test "optionally flushes all jobs regardless of delay" do
    DelayedJobTracker.start_link(:test_delayed_job_tracker)

    TestWorker
    |> JobPersistence.store_delayed_job(%{some: "data"}, delay_for: :infinity)
    |> DelayedJobTracker.register_job

    TestWorker
    |> JobPersistence.store_delayed_job(%{some: "data"}, delay_for: 10_000)
    |> DelayedJobTracker.register_job

    assert JobPersistence.delayed_jobs |> Enum.count == 2

    DelayedJobTracker.flush_all_jobs

    assert (wait with: lin_backoff(100, 1) |> expiry(1_000) do
      JobPersistence.delayed_jobs |> Enum.empty?
    end)
  end
end
