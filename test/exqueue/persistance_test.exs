defmodule Exredis.PeristanceTest do
  use ExUnit.Case

  def setup do
    Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])
  end

  defmodule SomeWorker do
  end

  test "can enqueue a job" do
    # as we rely on exact numbers here, let's clean out redis
    Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])

    Exqueue.Peristance.enqueue(SomeWorker, some: "data")
    Exqueue.Peristance.enqueue(SomeWorker, other: "data")

    assert Exqueue.Peristance.jobs == [
      %{ id: 1, worker: SomeWorker, opts: [ some: "data" ] },
      %{ id: 2, worker: SomeWorker, opts: [ other: "data" ] }
    ]

    Exqueue.Peristance.mark_as_finished(2)

    assert Exqueue.Peristance.jobs == [
      %{ id: 1, worker: SomeWorker, opts: [ some: "data" ] }
    ]
  end
end
