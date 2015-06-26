defmodule ExqueueTest do
  use ExUnit.Case

  defmodule TestWorker do
    def perform(arg) do
      send :exqueue_test, :job_has_been_run
    end
  end

  test "running jobs" do
    Process.register(self, :exqueue_test)

    Exqueue.add_worker(TestWorker)
    Exqueue.enqueue(TestWorker, 10)

    assert_receive :job_has_been_run
  end
end
