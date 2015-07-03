defmodule Exqueue.JobRunnerTest do
  use ExUnit.Case

  defmodule TestSuccessWorker do
    use Exqueue.Worker

    def perform(_opts) do
    end
  end

  defmodule TestErrorWorker do
    def perform(_opts) do
      raise "fail"
    end
  end

  defmodule TestCrashWorker do
    def perform(_opts) do
      Process.exit(self, "simulate an unknown error")
    end
  end

  test "a successful job runs return {:mark_as_finished, job}" do
    job = %{ worker: TestSuccessWorker, opts: [data: 10]}
    assert Exqueue.JobRunner.run_job(job) == {:mark_as_finished, job}
  end

  test "a job that raises an error returns {:mark_as_failed, job}" do
    job = %{ worker: TestErrorWorker, opts: [data: 10]}
    assert Exqueue.JobRunner.run_job(job) == {:mark_as_failed, job}
  end

  test "a job that crashes returns {:mark_as_failed, job}" do
    job = %{ worker: TestCrashWorker, opts: [data: 10]}
    assert Exqueue.JobRunner.run_job(job) == {:mark_as_failed, job}
  end
end
