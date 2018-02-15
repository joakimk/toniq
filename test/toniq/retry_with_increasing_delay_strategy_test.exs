defmodule Toniq.RetryWithIncreasingDelayTest do
  use ExUnit.Case

  test "retries 5 times" do
    assert Toniq.RetryWithIncreasingDelayStrategy.retry?(1) == true
    assert Toniq.RetryWithIncreasingDelayStrategy.retry?(2) == true
    assert Toniq.RetryWithIncreasingDelayStrategy.retry?(3) == true
    assert Toniq.RetryWithIncreasingDelayStrategy.retry?(4) == true
    assert Toniq.RetryWithIncreasingDelayStrategy.retry?(5) == true
    assert Toniq.RetryWithIncreasingDelayStrategy.retry?(6) == false
  end

  test "increases sleep time for each retry" do
    # 0.25 seconds
    assert Toniq.RetryWithIncreasingDelayStrategy.ms_to_sleep_before(1) == 250
    # 4 seconds
    assert Toniq.RetryWithIncreasingDelayStrategy.ms_to_sleep_before(2) == 4000
    # 20 seconds
    assert Toniq.RetryWithIncreasingDelayStrategy.ms_to_sleep_before(3) == 20250
    # 1 minute
    assert Toniq.RetryWithIncreasingDelayStrategy.ms_to_sleep_before(4) == 64000
    # 2.5 minutes
    assert Toniq.RetryWithIncreasingDelayStrategy.ms_to_sleep_before(5) == 156_250
  end
end
