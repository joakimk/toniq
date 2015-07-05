defmodule Exredis.PeristanceTest do
  use ExUnit.Case

  setup do
    Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])
    :ok
  end

  defmodule SomeWorker do
  end

  test "can store, fetch and mark a job as finished or failed" do
    # as we rely on exact numbers here, let's clean out redis
    Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])

    job1 = Toniq.Peristance.store_job(SomeWorker, some: "data")
    job2 = Toniq.Peristance.store_job(SomeWorker, other: "data")

    assert Toniq.Peristance.jobs == [job1, job2]

    Toniq.Peristance.mark_as_successful(job2)

    assert Toniq.Peristance.jobs == [job1]

    Toniq.Peristance.mark_as_failed(job1)
    assert Toniq.Peristance.jobs == []
    assert Toniq.Peristance.failed_jobs == [job1]
  end
end
