defmodule Exqueue.WorkerWatcher do
  def register_job(job) do

    # TODO: too simple implementation, but let's write more tests :)
    spawn_link fn ->
      IO.inspect "Running job: #{inspect(job)}"
      job.worker.perform(job.opts)
    end
    # one watcher per worker? per job?
  end
end
