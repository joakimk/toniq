defmodule Toniq.JobRunnerTest do
  use ExUnit.Case
  alias Toniq.Job

  defmodule TestWorker do
    use Toniq.Worker

    def perform(:succeed) do
    end

    def perform(:fail) do
      raise "failure"
    end
  end

  setup do
    Toniq.JobEvent.subscribe()
    on_exit(&Toniq.JobEvent.unsubscribe/0)
  end

  test "can run a job and report it as successful" do
    job = %Job{id: 1, worker: TestWorker, arguments: :succeed}

    Toniq.JobRunner.register_job(job)

    assert_receive {:finished, ^job}
  end

  @tag :capture_log
  test "can run a job and report it as failed" do
    job = %Job{id: 1, worker: TestWorker, arguments: :fail}

    Toniq.JobRunner.register_job(job)

    assert_receive {:failed, ^job}
  end

  # The job processor caught a gen_server message, didn't
  # seem like a problem at the time. Don't do that :)
  test "regression: can run two jobs in a row" do
    job1 = %Job{id: 1, worker: TestWorker, arguments: :succeed}
    job2 = %Job{id: 2, worker: TestWorker, arguments: :succeed}

    Toniq.JobRunner.register_job(job1)
    Toniq.JobRunner.register_job(job2)

    assert_receive {:finished, ^job1}
    assert_receive {:finished, ^job2}
  end
end
