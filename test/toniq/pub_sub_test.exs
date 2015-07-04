defmodule Toniq.PubSubTest do
  use ExUnit.Case

  test "publishing and subscribing to events" do
    Toniq.PubSub.subscribe

    # run out of the receiving process to ensure that works as well
    spawn_link fn ->
      Toniq.PubSub.publish
      Toniq.PubSub.publish
    end

    assert_receive :job_added
    assert_receive :job_added
  end
end
