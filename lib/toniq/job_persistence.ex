defmodule Toniq.JobPersistence do
  @moduledoc """
  Sets up peristences that make it easy to configure and swap adapters.
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      adapter = Keyword.fetch!(opts, :adapter)

      @doc """
      Stores a job.
      """
      defdelegate store(job, type, identifier \\ default_identifier()), to: adapter

      @doc """
      Fetch jobs.
      """
      defdelegate fetch(type, identifier \\ default_identifier()), to: adapter

      defdelegate jobs_key(type, identifier \\ default_identifier()), to: adapter

      # Only used internally by JobImporter
      defdelegate remove_from_incoming_jobs(job), to: adapter

      @doc """
      Marks a job as finished. This means that it's deleted from the persistence.
      """
      defdelegate mark_as_successful(job, identifier \\ default_identifier()), to: adapter

      @doc """
      Marks a job as failed. This removes the job from the regular list and stores
      it in the failed jobs list.
      """
      defdelegate mark_as_failed(job, error, identifier \\ default_identifier()), to: adapter

      @doc """
      Moves a failed job to the regular jobs list.

      Uses "job.vm" to do the operation in the correct namespace.
      """
      defdelegate move_failed_job_to_incoming_jobs(job_with_error), to: adapter

      @doc """
      Moves a delayed job to the regular jobs list.

      Uses "job.vm" to do the operation in the correct namespace.
      """
      defdelegate move_delayed_job_to_incoming_jobs(delayed_job), to: adapter

      @doc """
      Deletes a failed job.

      Uses "job.vm" to do the operation in the correct namespace.
      """
      defdelegate delete_failed_job(job), to: adapter

      defdelegate register_vm(identifier), to: adapter

      defdelegate update_alive_key(identifier, keepalive_expiration), to: adapter

      defdelegate update_alive_key(identifier, keepalive_expiration), to: adapter

      defdelegate registered_vms(), to: adapter

      defdelegate alive?(identifier), to: adapter

      defdelegate alive_vm_debug_info(identifier), to: adapter

      defdelegate takeover_jobs(from_identifier, to_identifier), to: adapter

      defp default_identifier, do: Toniq.Keepalive.identifier()
    end
  end

  def adapter, do: Application.get_env(:toniq, :persistence)
end
