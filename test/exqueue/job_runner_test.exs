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

  test "a successful job runs return {:job_was_successful, job}" do
    job = %{ worker: TestSuccessWorker, opts: [data: 10]}
    assert Exqueue.JobRunner.run_job(job) == {:job_was_successful, job}
  end

  test "a job that raises an error returns {:job_has_failed, job, error}" do
    job = %{ worker: TestErrorWorker, opts: [data: 10]}
    assert Exqueue.JobRunner.run_job(job) == {:job_has_failed, job, %RuntimeError{message: "fail"}}
  end

  test "a job that crashes returns {:job_has_failed, job, error}" do
    job = %{ worker: TestCrashWorker, opts: [data: 10]}
    assert Exqueue.JobRunner.run_job(job) == {:job_has_failed, job, %Exqueue.JobRunner.ProcessCrashError{message: "The job runner crashed. The reason that was given is: simulate an unknown error"}}
  end
end
