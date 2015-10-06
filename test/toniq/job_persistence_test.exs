defmodule Exredis.JobPersistenceTest do
  use ExUnit.Case

  setup do
    Process.whereis(:toniq_redis) |> Exredis.query([ "FLUSHDB" ])
    :ok
  end

  defmodule SomeWorker do
  end

  test "can persist job state" do
    job1 = Toniq.JobPersistence.store_job(SomeWorker, some: "data")
    job2 = Toniq.JobPersistence.store_job(SomeWorker, other: "data")

    assert Toniq.JobPersistence.jobs == [job1, job2]

    Toniq.JobPersistence.mark_as_successful(job2)

    assert Toniq.JobPersistence.jobs == [job1]

    Toniq.JobPersistence.mark_as_failed(job1)
    assert Toniq.JobPersistence.jobs == []
    assert Toniq.JobPersistence.failed_jobs == [job1]

    Toniq.JobPersistence.move_failed_job_to_jobs(job1)
    assert Toniq.JobPersistence.jobs == [job1]
    assert Toniq.JobPersistence.failed_jobs == []
  end

  test "can store and retrieve incoming jobs" do
    job = Toniq.JobPersistence.store_incoming_job(SomeWorker, incoming: "take cover")
    assert Toniq.JobPersistence.incoming_jobs == [job]
  end
end
