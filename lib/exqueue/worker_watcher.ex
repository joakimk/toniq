defmodule Exqueue.WorkerWatcher do
  def register_job(job) do
    IO.inspect "Got job: #{inspect(job)}"
  end
end
