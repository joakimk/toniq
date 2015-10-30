defmodule Toniq.RetryWithoutDelayStrategyTest do
  use ExUnit.Case

  test "retries 2 times" do
    assert Toniq.RetryWithoutDelayStrategy.retry?(1) == true
    assert Toniq.RetryWithoutDelayStrategy.retry?(2) == true
    assert Toniq.RetryWithoutDelayStrategy.retry?(3) == false
  end

  test "does not request any sleep between retries" do
    assert Toniq.RetryWithoutDelayStrategy.ms_to_sleep_before(2) == 0
  end
end
