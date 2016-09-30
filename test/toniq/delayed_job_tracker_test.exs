defmodule Toniq.DelayedJobTrackerTest do
  use ExUnit.Case

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

  test "can register and flush delayed jobs" do
    DelayedJobTracker.start_link(:test_delayed_job_tracker)

    TestWorker
    |> JobPersistence.store_delayed_job(%{some: "data"}, delay_for: 500)
    |> DelayedJobTracker.register_job

    TestWorker
    |> JobPersistence.store_delayed_job(%{some: "data"}, delay_for: 500)
    |> DelayedJobTracker.register_job

    assert JobPersistence.delayed_jobs |> Enum.count == 2

    :timer.sleep(1_000)

    assert JobPersistence.delayed_jobs |> Enum.empty?
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
end
