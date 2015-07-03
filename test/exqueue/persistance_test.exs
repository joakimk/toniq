defmodule Exredis.PeristanceTest do
  use ExUnit.Case

  setup do
    Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])
    :ok
  end

  defmodule SomeWorker do
  end

  test "can store, fetch and mark a job as finished" do
    # as we rely on exact numbers here, let's clean out redis
    Process.whereis(:redis) |> Exredis.query([ "FLUSHDB" ])

    Exqueue.Peristance.store_job(SomeWorker, some: "data")
    Exqueue.Peristance.store_job(SomeWorker, other: "data")

    assert Exqueue.Peristance.jobs == [
      %{ id: 1, worker: SomeWorker, opts: [ some: "data" ] },
      %{ id: 2, worker: SomeWorker, opts: [ other: "data" ] }
    ]

    Exqueue.Peristance.mark_as_finished(2)

    assert Exqueue.Peristance.jobs == [
      %{ id: 1, worker: SomeWorker, opts: [ some: "data" ] }
    ]
  end

  test "publishing and subscribing to events" do
    Exqueue.Peristance.subscribe_to_new_jobs

    # run out of the receiving process to ensure that works as well
    spawn_link fn ->
      Exqueue.Peristance.store_job(SomeWorker, some: "data")
      Exqueue.Peristance.store_job(SomeWorker, some: "data")
    end

    assert_receive :job_added
    assert_receive :job_added
  end
end
