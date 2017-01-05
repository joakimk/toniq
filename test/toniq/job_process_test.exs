defmodule Toniq.JobProcessTest do
  use ExUnit.Case

  defmodule TestSuccessWorker do
    use Toniq.Worker

    def perform(_arguments) do
    end
  end

  defmodule TestErrorWorker do
    def perform(_arguments) do
      raise "fail"
    end
  end

  defmodule TestCrashWorker do
    def perform(_arguments) do
      Process.exit(self(), "simulate an unknown error")
    end
  end

  @stacktrace [{Toniq.JobProcessTest.TestErrorWorker, :perform, 1,
                [file: 'test/toniq/job_process_test.exs', line: 13]},
               {Toniq.JobProcess, :run_job_and_capture_result, 1,
                [file: 'lib/toniq/job_process.ex', line: 25]},
               {Toniq.JobProcess, :"-run_job/1-fun-0-", 2,
                [file: 'lib/toniq/job_process.ex', line: 15]}]

  test "a successful job runs return {:job_was_successful, job}" do
    job = %{worker: TestSuccessWorker, arguments: [data: 10]}
    assert Toniq.JobProcess.run(job) == {:job_was_successful, job}
  end

  test "a job that raises an error returns {:job_has_failed, job, error, stack}" do
    job = %{worker: TestErrorWorker, arguments: [data: 10]}
    assert Toniq.JobProcess.run(job) == {:job_has_failed, job, %RuntimeError{message: "fail"}, @stacktrace}
  end

  test "a job that crashes returns {:job_has_failed, job, error, []}" do
    job = %{worker: TestCrashWorker, arguments: [data: 10]}
    assert Toniq.JobProcess.run(job) == {:job_has_failed, job, %Toniq.JobProcess.CrashError{message: "The job runner crashed. The reason that was given is: simulate an unknown error"}, []}
  end

  # regression
  test "when run twice, a failing job still returns job_has_failed" do
    job = %{worker: TestErrorWorker, arguments: [data: 10]}
    assert Toniq.JobProcess.run(job) == {:job_has_failed, job, %RuntimeError{message: "fail"}, @stacktrace}
    assert Toniq.JobProcess.run(job) == {:job_has_failed, job, %RuntimeError{message: "fail"}, @stacktrace}
  end
end
