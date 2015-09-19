# Used for manual testing of toniq
# Usage: Toniq.enqueue(Toniq.TestWorker)
defmodule Toniq.TestWorker do
  use Toniq.Worker

  def perform do
    IO.puts "Job started in #{Toniq.Keepalive.identifier}"
    :timer.sleep 3000
    IO.puts "Job finished in #{Toniq.Keepalive.identifier}"
  end
end
