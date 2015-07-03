defmodule Exqueue.PubSubTest do
  use ExUnit.Case

  test "publishing and subscribing to events" do
    Exqueue.PubSub.subscribe

    # run out of the receiving process to ensure that works as well
    spawn_link fn ->
      Exqueue.PubSub.publish
      Exqueue.PubSub.publish
    end

    assert_receive :job_added
    assert_receive :job_added
  end
end
