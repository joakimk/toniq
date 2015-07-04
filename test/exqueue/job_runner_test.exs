defmodule Exqueue.JobRunnerTest do
  use ExUnit.Case
  import CaptureLog

  defmodule TestWorker do
    use Exqueue.Worker

    def perform(:succeed) do
    end

    def perform(:fail) do
      raise "failure"
    end
  end

  setup do
    Exqueue.JobEvent.subscribe
    on_exit &Exqueue.JobEvent.unsubscribe/0
  end

  test "can run a job and report it as successful" do
    job = %{ id: 1, worker: TestWorker, opts: :succeed }

    Exqueue.JobRunner.register_job(job)

    assert_receive {:finished, job}
  end

  test "can run a job and report it as failed" do
    job = %{ id: 1, worker: TestWorker, opts: :fail }

    capture_log fn ->
      Exqueue.JobRunner.register_job(job)

      assert_receive {:failed, job}
    end
  end

  # TODO: does not run the same job twice
end
