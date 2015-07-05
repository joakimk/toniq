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

    assert_receive { :job_has_been_run, number_was: 10 }, 1000
    assert_receive { :finished, ^job }

    assert Toniq.Peristance.jobs == []
  end

  test "failing jobs are removed from the regular job list and stored in a failed jobs list" do
    logs = capture_log fn ->
      job = Toniq.enqueue(TestErrorWorker, data: 10)

      assert_receive { :failed, ^job }
      assert Toniq.Peristance.jobs == []
      assert Enum.count(Toniq.Peristance.failed_jobs) == 1
      assert (Toniq.Peristance.failed_jobs |> hd).worker == TestErrorWorker
    end

    assert logs =~ ~r/Job #\d: ToniqTest.TestErrorWorker.perform\(\[data: 10\]\) failed with error: %RuntimeError{message: "fail"}/
  end

  #test "can enqueue job without arguments"
  #test "can pick up jobs previosly stored in redis"
end
