defmodule Spawn do
  @doc """
  Spawns a linked process with a name. Useful to have if you want a well named process tree in :observer.start.
  """
  def spawn_link_with_name(name, function) do
    Process.whereis(name)
    |> spawn_link_with_name(name, function)
  end

  defp spawn_link_with_name(nil, name, function) do
    spawn_link(function)
    |> Process.register(name)
  end

  # Spawn without name if it's spawned more than once, for example
  # once by OTP and once by tests.
  defp spawn_link_with_name(pid, name, function) do
    spawn_link(function)
  end
end
