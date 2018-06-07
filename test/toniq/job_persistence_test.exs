defmodule Exredis.JobPersistenceTest do
  use ExUnit.Case

  alias Toniq.Job
  alias Toniq.RedisJobPersistence

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
      |> Job.new(some: "data")
      |> RedisJobPersistence.store(:jobs)

    job2 =
      SomeWorker
      |> Job.new(other: "data")
      |> RedisJobPersistence.store(:jobs)

    assert RedisJobPersistence.fetch(:jobs) == [job1, job2]

    RedisJobPersistence.mark_as_successful(job2)

    assert RedisJobPersistence.fetch(:jobs) == [job1]

    error = %Toniq.JobProcess.CrashError{message: "error"}
    job1_with_error = RedisJobPersistence.mark_as_failed(job1, error)
    assert RedisJobPersistence.fetch(:jobs) == []
    assert RedisJobPersistence.fetch(:failed_jobs) == [job1_with_error]

    RedisJobPersistence.move_failed_job_to_incoming_jobs(job1_with_error)
    assert RedisJobPersistence.fetch(:incoming_jobs) == [job1]
    assert RedisJobPersistence.fetch(:failed_jobs) == []
  end

  test "can store and move a delayed a job" do
    job =
      SomeWorker
      |> Job.new(%{some: "data"}, delay_for: 500)
      |> RedisJobPersistence.store(:delayed_jobs)

    assert RedisJobPersistence.fetch(:delayed_jobs) == [job]

    RedisJobPersistence.move_delayed_job_to_incoming_jobs(job)
    assert RedisJobPersistence.fetch(:incoming_jobs) == [job]
    assert RedisJobPersistence.fetch(:delayed_jobs) == []
  end

  test "can store and retrieve incoming jobs" do
    job =
      SomeWorker
      |> Job.new(%{some: "data"}, delay_for: 500)
      |> RedisJobPersistence.store(:incoming_jobs)

    assert RedisJobPersistence.fetch(:incoming_jobs) == [job]
  end

  test "can convert version 0 to version 1 jobs" do
    job = %{id: 1, worker: TestWorker, opts: [:a]}
    job_with_error = %{id: 2, error: "foo", worker: TestWorker, opts: [:a]}

    key = RedisJobPersistence.jobs_key(:jobs)

    Process.whereis(:toniq_redis)
    |> Exredis.query(["SADD", key, job])

    Process.whereis(:toniq_redis)
    |> Exredis.query(["SADD", key, job_with_error])

    assert Enum.count(RedisJobPersistence.fetch(:jobs)) == 2
    [job, job_with_error] = RedisJobPersistence.fetch(:jobs)

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
    assert RedisJobPersistence.mark_as_successful(job) == "1"
    assert RedisJobPersistence.mark_as_successful(job_with_error) == "1"
    assert Enum.count(RedisJobPersistence.fetch(:jobs)) == 0
  end
end
