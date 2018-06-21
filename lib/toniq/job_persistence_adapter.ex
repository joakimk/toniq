defmodule Toniq.JobPersistenceAdapter do
  @moduledoc """
  Behaviour for creating Job Persistence adapters
  The existing adapters are:
    - Toniq.RedisAdapter

  ## Example

    defmodule Toniq.CustomAdapter do
      @behaviour Toniq.JobPersistenceAdapter

      def store(job, job_type, identifier) do
        # store the job in some place
      end

      ...
    end
  """

  alias Toniq.Job

  @type job_type() :: :jobs | :incoming_jobs | :delayed_jobs | :failed_jobs

  @callback store(Job.t(), job_type(), String.t()) :: Job.t()

  @callback remove_from_incoming_jobs(Job.t(), String.t()) :: any()

  @callback fetch(job_type(), String.t()) :: [Job.t()]

  @callback mark_as_successful(Job.t(), String.t()) :: any()
  @callback mark_as_failed(Job.t(), any(), String.t()) :: Job.t()

  @callback move_failed_job_to_incoming_jobs(Job.t()) :: Job.t()
  @callback move_delayed_job_to_incoming_jobs(Job.t()) :: Job.t()
  @callback delete_failed_job(Job.t()) :: any()

  @callback jobs_key(atom(), String.t()) :: any()

  @callback register_vm(String.t()) :: any()
  @callback update_alive_key(String.t(), integer) :: any()
  @callback registered_vms() :: any()
  @callback alive?(String.t()) :: any()
  @callback alive_mv_debug_info(String.t()) :: any()
  @callback takeover_jobs(String.t(), String.t()) :: any()
end
