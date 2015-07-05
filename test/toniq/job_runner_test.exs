defmodule Toniq.JobRunnerTest do
  use ExUnit.Case
  import CaptureLog

  defmodule TestWorker do
    use Toniq.Worker

    def perform(:succeed) do
    end

    def perform(:fail) do
      raise "failure"
    end
  end

  setup do
    Toniq.JobEvent.subscribe
    on_exit &Toniq.JobEvent.unsubscribe/0
  end

  test "can run a job and report it as successful" do
    job = %{ id: 1, worker: TestWorker, opts: :succeed }

    Toniq.JobRunner.register_job(job)

    assert_receive {:finished, ^job}
  end

  test "can run a job and report it as failed" do
    job = %{ id: 1, worker: TestWorker, opts: :fail }

    capture_log fn ->
      Toniq.JobRunner.register_job(job)

      assert_receive {:failed, ^job}
    end
  end

  # The job processor caught a gen_server message, didn't
  # seem like a problem at the time. Don't do that :)
  test "regression: can run two jobs in a row" do
    job1 = %{ id: 1, worker: TestWorker, opts: :succeed }
    job2 = %{ id: 2, worker: TestWorker, opts: :succeed }

    Toniq.JobRunner.register_job(job1)
    Toniq.JobRunner.register_job(job2)

    assert_receive {:finished, ^job1}
    assert_receive {:finished, ^job2}
  end
end
