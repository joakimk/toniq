defmodule Toniq.JobProcessTest do
  use ExUnit.Case

  defmodule TestSuccessWorker do
    use Toniq.Worker

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
    job = %{worker: TestSuccessWorker, opts: [data: 10]}
    assert Toniq.JobProcess.run(job) == {:job_was_successful, job}
  end

  test "a job that raises an error returns {:job_has_failed, job, error}" do
    job = %{worker: TestErrorWorker, opts: [data: 10]}
    assert Toniq.JobProcess.run(job) == {:job_has_failed, job, %RuntimeError{message: "fail"}}
  end

  test "a job that crashes returns {:job_has_failed, job, error}" do
    job = %{worker: TestCrashWorker, opts: [data: 10]}
    assert Toniq.JobProcess.run(job) == {:job_has_failed, job, %Toniq.JobProcess.CrashError{message: "The job runner crashed. The reason that was given is: simulate an unknown error"}}
  end

  # regression
  test "when run twice, a failing job still returns job_has_failed" do
    job = %{worker: TestErrorWorker, opts: [data: 10]}
    assert Toniq.JobProcess.run(job) == {:job_has_failed, job, %RuntimeError{message: "fail"}}
    assert Toniq.JobProcess.run(job) == {:job_has_failed, job, %RuntimeError{message: "fail"}}
  end
end
