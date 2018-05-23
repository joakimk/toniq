defmodule Exredis.JobPersistenceTest do
  use ExUnit.Case
  alias Toniq.Job

  setup do
    Process.whereis(:toniq_redis) |> Exredis.query(["FLUSHDB"])
    :ok
  end

  defmodule SomeWorker do
    use Toniq.Worker

    def perform(_) do
    end
  end

  test "can persist job state" do
    job1 =
      SomeWorker
      |> Job.new([some: "data"])
      |> Toniq.JobPersistence.store_job()

    job2 =
      SomeWorker
      |> Job.new([other: "data"])
      |> Toniq.JobPersistence.store_job()

    assert Toniq.JobPersistence.jobs() == [job1, job2]

    Toniq.JobPersistence.mark_as_successful(job2)

    assert Toniq.JobPersistence.jobs() == [job1]

    error = %Toniq.JobProcess.CrashError{message: "error"}
    job1_with_error = Toniq.JobPersistence.mark_as_failed(job1, error)
    assert Toniq.JobPersistence.jobs() == []
    assert Toniq.JobPersistence.failed_jobs() == [job1_with_error]

    Toniq.JobPersistence.move_failed_job_to_incomming_jobs(job1_with_error)
    assert Toniq.JobPersistence.incoming_jobs() == [job1]
    assert Toniq.JobPersistence.failed_jobs() == []
  end

  test "can store and move a delayed a job" do
    job =
      SomeWorker
      |> Job.new(%{some: "data"}, delay_for: 500)
      |> Toniq.JobPersistence.store_delayed_job()
    assert Toniq.JobPersistence.delayed_jobs() == [job]

    Toniq.JobPersistence.move_delayed_job_to_incoming_jobs(job)
    assert Toniq.JobPersistence.incoming_jobs() == [job]
    assert Toniq.JobPersistence.delayed_jobs() == []
  end

  test "can store and retrieve incoming jobs" do
    job =
      SomeWorker
      |> Job.new(%{some: "data"}, delay_for: 500)
      |> Toniq.JobPersistence.store_incoming_job()
    assert Toniq.JobPersistence.incoming_jobs() == [job]
  end

  test "can convert version 0 to version 1 jobs" do
    job = %{id: 1, worker: TestWorker, opts: [:a]}
    job_with_error = %{id: 2, error: "foo", worker: TestWorker, opts: [:a]}

    key = Toniq.JobPersistence.jobs_key(Toniq.Keepalive.identifier())

    Process.whereis(:toniq_redis)
    |> Exredis.query(["SADD", key, job])

    Process.whereis(:toniq_redis)
    |> Exredis.query(["SADD", key, job_with_error])

    assert Enum.count(Toniq.JobPersistence.jobs()) == 2
    [job, job_with_error] = Toniq.JobPersistence.jobs()

    assert job == %Job{
             id: 1,
             worker: TestWorker,
             arguments: [:a],
             version: 1,
             vm: Toniq.Keepalive.identifier()
           }

    assert job.error == nil
    assert job_with_error.error == "foo"

    # Also converts the persisted job, so that we can mark jobs as successful, etc.
    assert Toniq.JobPersistence.mark_as_successful(job) == "1"
    assert Toniq.JobPersistence.mark_as_successful(job_with_error) == "1"
    assert Enum.count(Toniq.JobPersistence.jobs()) == 0
  end
end
