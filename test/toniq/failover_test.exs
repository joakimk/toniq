defmodule Toniq.FailoverTest do
  use ExUnit.Case

  setup do
    Process.whereis(:toniq_redis) |> Exredis.query([ "FLUSHDB" ])

    Toniq.FailoverTestHelper.spawn_and_connect("one")
    Toniq.FailoverTestHelper.spawn_and_connect("two")

    Toniq.FailoverTestHelper.add_job("one")
    Toniq.FailoverTestHelper.add_job("two")

    on_exit fn ->
      Toniq.FailoverTestHelper.halt("one")
      Toniq.FailoverTestHelper.halt("two")
    end
  end

  test "scopes jobs to each erlang vm and inherits jobs when one vm stops" do
    one = Toniq.FailoverTestHelper.get_state("one")
    two = Toniq.FailoverTestHelper.get_state("two")

    # Ensure we have two new system processes running
    assert one.system_pid != nil
    assert two.system_pid != nil
    assert one.system_pid != two.system_pid

    # WIP:
  end
  #  assert Enum.count(one.jobs) == 1
  #  assert Enum.count(two.jobs) == 1
  #
  #  Toniq.FailoverTestHelper.halt("one")
  #
  #  :timer.sleep 1000
  #  assert Enum.count(two.jobs) == 2
  #
  #  Toniq.FailoverTestHelper.halt("two")
  #  Toniq.FailoverTestHelper.spawn_and_connect("one")
  #
  #  :timer.sleep 1000
  #  assert Enum.count(one.jobs) == 2
  #end
end
