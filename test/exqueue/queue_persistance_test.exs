defmodule Exredis.QueuePeristanceTest do
  use ExUnit.Case

  def setup do
    Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])
  end

  defmodule SomeWorker do
  end

  test "can enqueue a job" do
    # as we rely on exact numbers here, let's clean out redis
    Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])

    Exqueue.QueuePeristance.enqueue(SomeWorker, some: "data")
    Exqueue.QueuePeristance.enqueue(SomeWorker, other: "data")

    assert Exqueue.QueuePeristance.jobs == [
      %{ id: 1, worker: SomeWorker, opts: [ some: "data" ] },
      %{ id: 2, worker: SomeWorker, opts: [ other: "data" ] }
    ]

    Exqueue.QueuePeristance.mark_as_finished(2)

    assert Exqueue.QueuePeristance.jobs == [
      %{ id: 1, worker: SomeWorker, opts: [ some: "data" ] }
    ]
  end
end
