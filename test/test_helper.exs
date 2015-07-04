ExUnit.start()

defmodule CaptureLog do
  import ExUnit.CaptureIO

  # Borrowed from elixir test helper, is built into elixir in master
  def capture_log(level \\ :debug, fun) do
    Logger.configure(level: level)
    capture_io(:user, fn ->
      fun.()
      Logger.flush()
    end)
  after
    Logger.configure(level: :debug)
  end
end
