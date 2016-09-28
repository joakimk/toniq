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

    error = %Toniq.JobProcess.CrashError{message: "error"}
    job1_with_error = Toniq.JobPersistence.mark_as_failed(job1, error)
    assert Toniq.JobPersistence.jobs == []
    assert Toniq.JobPersistence.failed_jobs == [job1_with_error]

    Toniq.JobPersistence.move_failed_job_to_incomming_jobs(job1_with_error)
    assert Toniq.JobPersistence.incoming_jobs == [job1]
    assert Toniq.JobPersistence.failed_jobs == []
  end

  test "can store and move a delayed a job" do
    job = Toniq.JobPersistence.store_delayed_job(SomeWorker, some: "data")
    assert Toniq.JobPersistence.delayed_jobs == [job]

    Toniq.JobPersistence.move_delayed_job_to_incoming_jobs(job)
    assert Toniq.JobPersistence.incoming_jobs == [job]
    assert Toniq.JobPersistence.delayed_jobs == []
  end

  test "can store and retrieve incoming jobs" do
    job = Toniq.JobPersistence.store_incoming_job(SomeWorker, incoming: "take cover")
    assert Toniq.JobPersistence.incoming_jobs == [job]
  end

  test "can convert version 0 to version 1 jobs" do
    job = %{id: 1, worker: TestWorker, opts: [:a]}
    key = Toniq.JobPersistence.jobs_key(Toniq.Keepalive.identifier)
    Process.whereis(:toniq_redis) |> Exredis.query(["SADD", key, job])

    assert Enum.count(Toniq.JobPersistence.jobs) == 1
    job = Toniq.JobPersistence.jobs |> hd
    assert job == %{
      id: 1,
      worker: TestWorker,
      arguments: [:a],
      version: 1,
      vm: Toniq.Keepalive.identifier
    }

    # Also converts the persisted job, so that we can mark jobs as successful, etc.
    Toniq.JobPersistence.mark_as_successful(job)
    assert Enum.count(Toniq.JobPersistence.jobs) == 0
  end
end
