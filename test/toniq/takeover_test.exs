# WIP: Not used by Toniq yet

defmodule Toniq.TakeoverTest do
  use ExUnit.Case

  setup do
    Process.whereis(:toniq_redis) |> Exredis.query([ "FLUSHDB" ])
    Agent.start_link(fn -> 1 end, name: :fake_system_process_id)
    :ok
  end

  defmodule SomeWorker do
  end

  test "generates a uuid that remains the same after app boot" do
    app1 = spawn &app_process/0

    # Get the current uuid and job count
    send app1, { :get_state, self }
    assert_receive %{ uuid: uuid }

    assert String.length(uuid) == 36

    # Assert the uuid and job_count does not change
    send app1, { :get_state, self }
    assert_receive %{ uuid: ^uuid }
  end

  test "generates a different uuid in each erlang vm based on system pid" do
    app1 = spawn &app_process/0
    app2 = spawn &app_process/0

    send app1, { :get_state, self }
    assert_receive %{ uuid: uuid1 }

    send app2, { :get_state, self }
    assert_receive %{ uuid: uuid2 }

    assert uuid1 != uuid2
  end

  #test "jobs from a missing app can be taken over by another app"
    # start first app
    # start second app
    # ensure it does not see the first app's jobs

    # kill the first app
    # assert that the second app has taken over the jobs

  #test "an app changes uuid if it can't write to redis within ...?"

  defp app_process do
    system_id = Agent.get_and_update(:fake_system_process_id, fn (last_id) -> {last_id + 1, last_id + 1} end)

    Toniq.Takeover.start_link(system_id)
    Toniq.Persistence.store_job(SomeWorker, some: "data1")
    Toniq.Persistence.store_job(SomeWorker, some: "data2")

    app_process(system_id)
  end

  defp app_process(system_id) do
    receive do
      { :get_state, test_process } ->
        job_count = Enum.count(Toniq.Persistence.jobs)
        send test_process, %{ uuid: Toniq.Takeover.uuid(system_id), job_count: job_count }
    end

    app_process(system_id)
  end
end
