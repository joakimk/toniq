defmodule Exredis.PersistenceTest do
  use ExUnit.Case

  setup do
    Process.whereis(:toniq_redis) |> Exredis.query([ "FLUSHDB" ])
    :ok
  end

  defmodule SomeWorker do
  end

  test "can store, fetch and mark a job as finished or failed" do
    # as we rely on exact numbers here, let's clean out redis
    Process.whereis(:toniq_redis) |> Exredis.query([ "FLUSHDB" ])

    job1 = Toniq.Persistence.store_job(SomeWorker, some: "data")
    job2 = Toniq.Persistence.store_job(SomeWorker, other: "data")

    assert Toniq.Persistence.jobs == [job1, job2]

    Toniq.Persistence.mark_as_successful(job2)

    assert Toniq.Persistence.jobs == [job1]

    Toniq.Persistence.mark_as_failed(job1)
    assert Toniq.Persistence.jobs == []
    assert Toniq.Persistence.failed_jobs == [job1]
  end
end
