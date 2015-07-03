defmodule Exredis.PeristanceTest do
  use ExUnit.Case

  setup do
    Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])
    :ok
  end

  defmodule SomeWorker do
  end

  test "can store, fetch and mark a job as finished or failed" do
    # as we rely on exact numbers here, let's clean out redis
    Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])

    Exqueue.Peristance.store_job(SomeWorker, some: "data")
    Exqueue.Peristance.store_job(SomeWorker, other: "data")

    job1 = %{ id: 1, worker: SomeWorker, opts: [ some: "data" ] }
    job2 = %{ id: 2, worker: SomeWorker, opts: [ other: "data" ] }

    assert Exqueue.Peristance.jobs == [ job1, job2 ]

    Exqueue.Peristance.mark_as_finished(job2)

    assert Exqueue.Peristance.jobs == [ job1 ]
  end
end
