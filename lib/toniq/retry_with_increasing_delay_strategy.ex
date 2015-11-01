defmodule Toniq.RetryWithIncreasingDelayStrategy do
  @moduledoc """
  Default retry strategy:
  - Will retry jobs 5 times after the initial attempt.
  - Waits 250 ms before the first try, then 4 seconds, then 20 seconds,
    then 1 minute and finally 2.5 minutes before the last try.
  """

  # NOTE: Update README, docs and tests if you change this
  def retry?(attempt) when attempt < 6, do: true
  def retry?(_attempt), do: false

  # NOTE: Update README, docs and tests if you change this
  def ms_to_sleep_before(attempt), do: :math.pow(attempt, 4) * 250
end
