defmodule ExqueueTest do
  use ExUnit.Case

  defmodule TestWorker do
    use Exqueue.Worker

    def perform(arg) do
      send :exqueue_test, { :job_has_been_run, arg_was: arg }
    end
  end

  #defmodule TestErrorWorker do
  #  def perform(arg) do
  #    raise "fail"
  #  end
  #end

  test "running jobs" do
    Process.register(self, :exqueue_test)

    Exqueue.enqueue(TestWorker, 10)

    assert_receive { :job_has_been_run, arg_was: 10 }
  end

  # how the error appears and when depends on how jobs are run
  #test "a job can fail" do
  #  Process.register(self, :exqueue_test)
  #  Exqueue.enqueue(TestErrorWorker, 10)
  #end

  #test "failing when there is no running workers"
end
