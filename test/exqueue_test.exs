defmodule ExqueueTest do
  use ExUnit.Case

  defmodule TestWorker do
    use Exqueue.Worker

    def perform(data: number) do
      send :exqueue_test, { :job_has_been_run, number_was: number }
    end
  end

  defmodule TestErrorWorker do
    def perform(arg) do
      raise "fail"
    end
  end

  setup do
    Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])
    :ok
  end

  test "running jobs" do
    Process.register(self, :exqueue_test)

    Exqueue.enqueue(TestWorker, data: 10)

    assert_receive { :job_has_been_run, number_was: 10 }, 1000

    wait_for_persistance_update
    assert Exqueue.Peristance.jobs == []
  end

  test "failing jobs are removed from the regular job list and stored in a failed jobs list" do
    Exqueue.enqueue(TestErrorWorker, data: 10)

    raise "This is a pending test"

    wait_for_persistance_update
    assert Exqueue.Peristance.jobs == []
    assert Enum.length(Exqueue.Peristance.failed_jobs) == 1
    assert (Exqueue.Peristance.failed_jobs |> hd).first.worker == TestErrorWorker
  end

  defp wait_for_persistance_update do
    # Need to wait for the job to be marked as processed
    # TODO: see if there is any way to know when a job fully processed
    :timer.sleep 50
  end

  # TODO: avoid running duplicate jobs since the polling will continue to re-add them?

  #test "can enqueue job without arguments"
  #test "can pick up jobs previosly stored in redis"

  # how the error appears and when depends on how jobs are run
  #test "a job can fail" do
  #  Process.register(self, :exqueue_test)
  #  Exqueue.enqueue(TestErrorWorker, 10)
  #end

  #test "failing when there is no running workers"
end
