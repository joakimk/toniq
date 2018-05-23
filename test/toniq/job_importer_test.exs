defmodule Exredis.JobImporterTest do
  use ExUnit.Case
  alias Toniq.Job

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
    |> Toniq.JobPersistence.store_incoming_job()

    assert_receive :job_has_been_run, 1000
    # wait for job to be removed
    :timer.sleep(1)

    assert Toniq.JobPersistence.jobs() == []
    assert Toniq.JobPersistence.incoming_jobs() == []
  end
end
