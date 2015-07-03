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

  test "running jobs" do
    Process.register(self, :exqueue_test)

    Exqueue.enqueue(TestWorker, data: 10)

    assert_receive { :job_has_been_run, number_was: 10 }
  end

  #test "failing jobs are removed from the regular job list and stored in a failed jobs list" do
  #end

  #test "can enqueue job without arguments"
  #test "can pick up jobs previosly stored in redis"

  # how the error appears and when depends on how jobs are run
  #test "a job can fail" do
  #  Process.register(self, :exqueue_test)
  #  Exqueue.enqueue(TestErrorWorker, 10)
  #end

  #test "failing when there is no running workers"
end
