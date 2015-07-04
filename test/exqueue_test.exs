defmodule ExqueueTest do
  use ExUnit.Case
  import CaptureLog

  defmodule TestWorker do
    use Exqueue.Worker

    def perform(data: number) do
      send :exqueue_test, { :job_has_been_run, number_was: number }
    end
  end

  defmodule TestErrorWorker do
    use Exqueue.Worker

    def perform(_arg) do
      raise "fail"
    end
  end

  setup do
    Exqueue.JobEvent.subscribe
    on_exit &Exqueue.JobEvent.unsubscribe/0
  end

  setup do
    Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])
    :ok
  end

  test "running jobs" do
    Process.register(self, :exqueue_test)

    Exqueue.enqueue(TestWorker, data: 10)

    assert_receive { :job_has_been_run, number_was: 10 }, 1000
    assert_receive { :finished, job }

    assert Exqueue.Peristance.jobs == []
  end

  test "failing jobs are removed from the regular job list and stored in a failed jobs list" do
    logs = capture_log fn ->
      Exqueue.enqueue(TestErrorWorker, data: 10)

      assert_receive { :failed, job }
      assert Exqueue.Peristance.jobs == []
      assert Enum.count(Exqueue.Peristance.failed_jobs) == 1
      assert (Exqueue.Peristance.failed_jobs |> hd).worker == TestErrorWorker
    end

    assert logs =~ ~r/Job #\d: ExqueueTest.TestErrorWorker.perform\(\[data: 10\]\) failed with error: %RuntimeError{message: "fail"}/
  end

  #test "can enqueue job without arguments"
  #test "can pick up jobs previosly stored in redis"
end
