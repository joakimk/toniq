defmodule ToniqTest do
  use ExUnit.Case
  import CaptureLog
  alias Toniq.Job

  defmodule TestWorker do
    use Toniq.Worker

    def perform(data: number) do
      send(:toniq_test, {:job_has_been_run, number_was: number})
    end
  end

  defmodule TestErrorWorker do
    use Toniq.Worker

    def perform(_arg) do
      send(:toniq_test, :job_has_been_run)
      raise "fail"
    end
  end

  defmodule TestNoArgumentsWorker do
    use Toniq.Worker

    def perform do
    end
  end

  defmodule TestMaxConcurrencyWorker do
    use Toniq.Worker, max_concurrency: 2

    def perform(process_name) do
      add_to_list(process_name)

      Process.register(self(), process_name)

      receive do
        :stop -> nil
      end

      remove_from_list(process_name)
    end

    def currently_running_job_names, do: Agent.get(agent(), fn names -> names end)

    defp add_to_list(process_name),
      do: Agent.update(agent(), fn list -> list ++ [process_name] end)

    defp remove_from_list(process_name),
      do: Agent.update(agent(), fn list -> list -- [process_name] end)

    defp agent, do: Process.whereis(:job_list)
  end

  setup do
    Toniq.JobEvent.subscribe()
    Process.register(self(), :toniq_test)
    Process.whereis(:toniq_redis) |> Exredis.query(["FLUSHDB"])
    on_exit(&Toniq.JobEvent.unsubscribe/0)
  end

  setup do
    Process.whereis(:toniq_redis) |> Exredis.query(["FLUSHDB"])
    Toniq.RedisJobPersistence.register_vm(Toniq.Keepalive.identifier())
    :ok
  end

  test "running jobs" do
    job = Toniq.enqueue(TestWorker, data: 10)

    assert_receive {:job_has_been_run, number_was: 10}
    assert_receive {:finished, ^job}

    # allow persistence some time to remove the job
    :timer.sleep(1)
    assert Toniq.RedisJobPersistence.fetch(:jobs) == []
  end

  test "failing jobs are removed from the regular job list and stored in a failed jobs list" do
    logs =
      capture_log(fn ->
        job = Toniq.enqueue(TestErrorWorker, data: 10)

        assert_receive {:failed, ^job}
        assert Toniq.RedisJobPersistence.fetch(:jobs) == []
        assert Enum.count(Toniq.RedisJobPersistence.fetch(:failed_jobs)) == 1
        assert (Toniq.RedisJobPersistence.fetch(:failed_jobs) |> hd).worker == TestErrorWorker
      end)

    assert logs =~
             ~r/Job #\d: ToniqTest.TestErrorWorker.perform\(\[data: 10\]\) failed with error: %RuntimeError{message: "fail"}/
  end

  @tag :capture_log
  test "failing jobs are automatically retried" do
    job = Toniq.enqueue(TestErrorWorker, data: 10)

    assert_receive :job_has_been_run
    assert_receive :job_has_been_run
    assert_receive :job_has_been_run
    refute_receive :job_has_been_run

    assert_receive {:failed, ^job}
  end

  @tag :capture_log
  test "failed jobs can be retried" do
    job = Toniq.enqueue(TestErrorWorker, data: 10)
    assert_receive {:failed, ^job}
    assert Enum.count(Toniq.failed_jobs()) == 1

    job = Toniq.failed_jobs() |> hd
    assert Toniq.retry(job)

    assert_receive {:failed, _job}
    assert Enum.count(Toniq.failed_jobs()) == 1
  end

  @tag :capture_log
  test "failed jobs can be deleted" do
    job = Toniq.enqueue(TestErrorWorker, data: 10)
    assert_receive {:failed, ^job}
    assert Enum.count(Toniq.failed_jobs()) == 1

    job = Toniq.failed_jobs() |> hd
    assert Toniq.delete(job)

    assert Toniq.failed_jobs() == []
  end

  test "can handle jobs from another VM for some actions (for easy administration of failed jobs)" do
    Toniq.RedisJobPersistence.register_vm("other")
    Toniq.RedisJobPersistence.update_alive_key("other", 1000)

    job =
      TestWorker
      |> Job.new([])
      |> Toniq.RedisJobPersistence.store(:jobs)

    Toniq.RedisJobPersistence.mark_as_failed(job, "error", "other")

    assert Enum.count(Toniq.failed_jobs()) == 1
    job = Toniq.failed_jobs() |> hd
    assert job.vm == "other"

    Toniq.delete(job)
    assert Toniq.failed_jobs() == []
  end

  test "can be conventiently called within a pipeline" do
    [data: 10]
    |> Toniq.enqueue_to(TestWorker)

    assert_receive {:job_has_been_run, number_was: 10}
  end

  test "can run jobs without arguments" do
    job = Toniq.enqueue(TestNoArgumentsWorker)
    assert_receive {:finished, ^job}
  end

  test "can limit concurrency of jobs" do
    {:ok, _pid} = Agent.start_link(fn -> [] end, name: :job_list)

    assert TestWorker.max_concurrency() == :unlimited
    assert TestMaxConcurrencyWorker.max_concurrency() == 2

    job1 = Toniq.enqueue(TestMaxConcurrencyWorker, :job1)
    job2 = Toniq.enqueue(TestMaxConcurrencyWorker, :job2)
    job3 = Toniq.enqueue(TestMaxConcurrencyWorker, :job3)
    job4 = Toniq.enqueue(TestMaxConcurrencyWorker, :job4)

    # wait for jobs to boot up
    :timer.sleep(1)

    assert currently_running_job_names() == [:job1, :job2]

    send(:job1, :stop)
    assert_receive {:finished, ^job1}
    assert currently_running_job_names() == [:job2, :job3]

    send(:job2, :stop)
    assert_receive {:finished, ^job2}
    assert currently_running_job_names() == [:job3, :job4]

    send(:job3, :stop)
    assert_receive {:finished, ^job3}
    assert currently_running_job_names() == [:job4]

    send(:job4, :stop)
    assert_receive {:finished, ^job4}
    assert currently_running_job_names() == []
  end

  # regression
  test "can enqueue more jobs after limiting jobs once" do
    {:ok, _pid} = Agent.start_link(fn -> [] end, name: :job_list)

    Toniq.enqueue(TestMaxConcurrencyWorker, :job1)
    job2 = Toniq.enqueue(TestMaxConcurrencyWorker, :job2)
    Toniq.enqueue(TestMaxConcurrencyWorker, :job3)

    # wait for jobs to boot up
    :timer.sleep(1)

    send(:job1, :stop)
    send(:job2, :stop)
    assert_receive {:finished, ^job2}
    send(:job3, :stop)

    Toniq.enqueue(TestMaxConcurrencyWorker, :job4)
    Toniq.enqueue(TestMaxConcurrencyWorker, :job5)
    job6 = Toniq.enqueue(TestMaxConcurrencyWorker, :job6)

    # wait for jobs to boot up
    :timer.sleep(1)

    assert currently_running_job_names() == [:job4, :job5]

    # Stop everything before running other tests
    send(:job4, :stop)
    send(:job5, :stop)
    :timer.sleep(1)
    send(:job6, :stop)
    assert_receive {:finished, ^job6}
  end

  defp currently_running_job_names do
    Enum.sort(TestMaxConcurrencyWorker.currently_running_job_names())
  end
end
