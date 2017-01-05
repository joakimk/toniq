defmodule Toniq.JobEventTest do
  use ExUnit.Case

  test "can send events to multiple subscribers" do
    test_pid = self()

    spawn_link fn ->
      Toniq.JobEvent.subscribe
      receive do
        {:finished, job} -> send test_pid, {:one, job.id}
      end
    end

    spawn_link fn ->
      Toniq.JobEvent.subscribe

      :timer.sleep 1 # make sure this runs after :one
      receive do
        {:finished, job} -> send test_pid, {:two, job.id}
      end
    end

    :timer.sleep 1

    job = %{id: 1}
    Toniq.JobEvent.finished(job)

    assert_receive {:one, 1}
    assert_receive {:two, 1}
  end

  test "can be unsubscribed" do
    Toniq.JobEvent.subscribe

    job = %{}
    Toniq.JobEvent.finished(job)
    assert_receive {:finished, ^job}

    Toniq.JobEvent.unsubscribe

    Toniq.JobEvent.finished(job)
    refute_receive {:finished, ^job}
  end
end
