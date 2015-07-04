# Represents the queue of jobs in memory and how to load them from redis. For now there is only one.

defmodule Toniq.Queue do
  use GenServer

  def register_job(worker_module, opts) do
    # todo:
    # save in redis
    # save in memory
    # cast to Worker that we want a job run
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end
end
