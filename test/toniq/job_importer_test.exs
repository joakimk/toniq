defmodule Exredis.JobImporterTest do
  use ExUnit.Case
  alias Toniq.Job
  alias Toniq.RedisJobPersistence

  defmodule TestWorker do
    use Toniq.Worker

    def perform(_) do
      send(:toniq_job_importer_test, :job_has_been_run)
    end
  end

  setup do
    Process.whereis(:toniq_redis) |> Exredis.query(["FLUSHDB"])
    :ok
  end

  @tag :capture_log
  test "imports jobs from the incoming_jobs queue" do
    Process.register(self(), :toniq_job_importer_test)

    TestWorker
    |> Job.new([])
    |> RedisJobPersistence.store(:incoming_jobs)

    assert_receive :job_has_been_run, 1000
    # wait for job to be removed
    :timer.sleep(1)

    assert RedisJobPersistence.fetch(:jobs) == []
    assert RedisJobPersistence.fetch(:incoming_jobs) == []
  end
end
