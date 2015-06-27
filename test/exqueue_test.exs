defmodule ExqueueTest do
  use ExUnit.Case

  defmodule TestWorker do
    def perform(arg) do
      send :exqueue_test, :job_has_been_run
    end
  end

  defmodule TestErrorWorker do
    def perform(arg) do
      raise "fail"
    end
  end

  test "running jobs" do
    Process.register(self, :exqueue_test)

    Exqueue.start_worker(TestWorker)
    Exqueue.enqueue(TestWorker, 10)

    assert_receive :job_has_been_run
  end

  test "will not run jobs when there are no running workers" do
    Process.register(self, :exqueue_test)

    Exqueue.enqueue(TestWorker, 10)

    refute_receive :job_has_been_run
  end

  # how the error appears and when depends on how jobs are run
  #test "a job can fail" do
  #  Process.register(self, :exqueue_test)

  #  Exqueue.start_worker(TestErrorWorker)
  #  Exqueue.enqueue(TestErrorWorker, 10)
  #end

  #test "jobs will be picked up if a worker starts after a job has been enqueued"
  #test "failing when there is no running workers"
end
