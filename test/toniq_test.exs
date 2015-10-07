defmodule ToniqTest do
  use ExUnit.Case
  import CaptureLog

  defmodule TestWorker do
    use Toniq.Worker

    def perform(data: number) do
      send :toniq_test, { :job_has_been_run, number_was: number }
    end
  end

  defmodule TestErrorWorker do
    use Toniq.Worker

    def perform(_arg) do
      raise "fail"
    end
  end

  defmodule TestNoArgumentsWorker do
    use Toniq.Worker

    def perform do
    end
  end

  setup do
    Toniq.JobEvent.subscribe
    on_exit &Toniq.JobEvent.unsubscribe/0
  end

  setup do
    Process.whereis(:toniq_redis) |> Exredis.query([ "FLUSHDB" ])
    :ok
  end

  test "running jobs" do
    Process.register(self, :toniq_test)

    job = Toniq.enqueue(TestWorker, data: 10)

    assert_receive { :job_has_been_run, number_was: 10 }
    assert_receive { :finished, ^job }

    :timer.sleep 1 # allow persistence some time to remove the job
    assert Toniq.JobPersistence.jobs == []
  end

  test "failing jobs are removed from the regular job list and stored in a failed jobs list" do
    logs = capture_log fn ->
      job = Toniq.enqueue(TestErrorWorker, data: 10)

      assert_receive { :failed, ^job }
      assert Toniq.JobPersistence.jobs == []
      assert Enum.count(Toniq.JobPersistence.failed_jobs) == 1
      assert (Toniq.JobPersistence.failed_jobs |> hd).worker == TestErrorWorker
    end

    assert logs =~ ~r/Job #\d: ToniqTest.TestErrorWorker.perform\(\[data: 10\]\) failed with error: %RuntimeError{message: "fail"}/
  end

  test "failed jobs can be retried" do
    capture_log fn ->
      job = Toniq.enqueue(TestErrorWorker, data: 10)
      assert_receive { :failed, ^job }
      assert Toniq.JobPersistence.failed_jobs == [job]

      assert Toniq.retry(job)

      assert_receive { :failed, ^job }
      assert Toniq.JobPersistence.failed_jobs == [job]
    end
  end

  test "failed jobs can be deleted" do
    capture_log fn ->
      job = Toniq.enqueue(TestErrorWorker, data: 10)
      assert_receive { :failed, ^job }
      assert Toniq.JobPersistence.failed_jobs == [job]

      assert Toniq.delete(job)

      assert Toniq.JobPersistence.failed_jobs == []
    end
  end

  test "can be conventiently called within a pipeline" do
    Process.register(self, :toniq_test)

    [data: 10]
    |> Toniq.enqueue_to(TestWorker)

    assert_receive { :job_has_been_run, number_was: 10 }
  end

  test "can run jobs without arguments" do
    job = Toniq.enqueue(TestNoArgumentsWorker)
    assert_receive { :finished, ^job }
  end
end
