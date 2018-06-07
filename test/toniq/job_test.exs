defmodule Toniq.JobTest do
  use ExUnit.Case
  alias Toniq.Job

  defmodule SomeWorker do
  end

  test "builds a job without options" do
    job = Job.new(SomeWorker, %{some: "data"})

    assert job == %Job{
             worker: SomeWorker,
             arguments: %{some: "data"},
             version: 1,
             options: nil
           }
  end

  test "builds a job with a delay" do
    job = Job.new(SomeWorker, %{some: "data"}, delay_for: 3_000)
    expiry = :os.system_time(:milli_seconds) + 3_000

    assert job.id == nil
    assert job.worker == SomeWorker
    assert job.arguments == %{some: "data"}
    assert job.version == 1
    assert_in_delta(Keyword.get(job.options, :delayed_until), expiry, 10)
  end
end
