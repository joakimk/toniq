defmodule Toniq.RetryWithoutDelayStrategy do
  @moduledoc """
  The simplest retry strategy:
  - Retries 2 times after the initial try for a total of 3 runs
  - Retries right away without waiting when a job fails
  """

  def retry?(attempt) when attempt <= 2, do: true
  def retry?(_attempt), do: false

  def ms_to_sleep_before(_attempt), do: 0 # no waiting between attempts
end
