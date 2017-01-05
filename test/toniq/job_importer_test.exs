defmodule Exredis.JobImporterTest do
  use ExUnit.Case

  defmodule TestWorker do
    use Toniq.Worker

    def perform(_) do
      send :toniq_job_importer_test, :job_has_been_run
    end
  end

  setup do
    Process.whereis(:toniq_redis) |> Exredis.query(["FLUSHDB"])
    :ok
  end

  @tag :capture_log
  test "imports jobs from the incoming_jobs queue" do
    Process.register self(), :toniq_job_importer_test
    Toniq.JobPersistence.store_incoming_job(TestWorker, data: 10)

    assert_receive :job_has_been_run, 1000
    :timer.sleep 1 # wait for job to be removed

    assert Toniq.JobPersistence.jobs == []
    assert Toniq.JobPersistence.incoming_jobs == []
  end
end
