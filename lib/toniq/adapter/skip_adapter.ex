defmodule Toniq.SkipAdapter do
  @moduledoc """
  Persistance Adapter for Agent

  ## Example config
      # In config/config.exs, or config.prod.exs, etc.
      config :toniq,
        persistence: Toniq.SkipJobPersistence
  """

  @behaviour Toniq.JobPersistenceAdapter

  alias Toniq.Job

  def store(job, type, identifier) do
    store_job_in_key(job, jobs_key(type, identifier), identifier)
  end

  def jobs_key(type, identifier) do
    identifier_scoped_key(type, identifier)
  end

  @doc """
  Returns all jobs
  """
  def fetch(type, identifier \\ default_identifier()) do
    load_jobs(jobs_key(type, identifier), identifier)
  end

  # Only used internally by JobImporter
  def remove_from_incoming_jobs(job, identifier \\ default_identifier()) do
  end

  def mark_as_successful(job, identifier \\ default_identifier()) do
  end

  def mark_as_failed(job, error, identifier \\ default_identifier()) do
  end

  def move_failed_job_to_incoming_jobs(job_with_error) do
    job_with_error
  end

  def move_delayed_job_to_incoming_jobs(delayed_job) do
    delayed_job
  end

  def delete_failed_job(job) do
  end

  def register_vm(identifier) do
  end

  def update_alive_key(identifier, keepalive_expiration) do
  end

  def registered_vms do
    []
  end

  def alive?(identifier) do
    true
  end

  def alive_vm_debug_info(identifier) do
  end

  def takeover_jobs(from_identifier, to_identifier) do
  end

  # Added so we could use it to default scope further out when we want to allow custom persistance scopes in testing.
  defp default_scope, do: "empty"

  defp incoming_jobs_key(identifier) do
    jobs_key(:incoming_jobs, identifier)
  end

  defp jobs_key(identifier) do
    jobs_key(:jobs, identifier)
  end

  defp failed_jobs_key(identifier) do
    jobs_key(:failed_jobs, identifier)
  end

  defp delayed_jobs_key(identifier) do
    jobs_key(:delayed_jobs, identifier)
  end

  # This is not a API any production code should rely upon, but could be useful
  # info when debugging or to verify things in tests.
  defp debug_info, do: %{system_pid: System.get_pid(), last_updated_at: system_time()}

  # R17 version of R18's :erlang.system_time
  defp system_time, do: :timer.now_diff(:erlang.now(), {0, 0, 0}) * 1000

  defp alive_key(identifier), do: "#{default_scope()}:#{identifier}:alive"
  defp registered_vms_key, do: "#{default_scope()}:registered_vms"

  defp identifier_scoped_key(key, identifier) do
    prefix = Application.get_env(:toniq, :redis_key_prefix)
    "#{prefix}:#{identifier}:#{key}"
  end

  defp store_job_in_key(job, key, identifier) do
    job_id = UUID.uuid4()

    job =
      job
      |> Job.set_id(job_id)
      |> Job.add_vm_identifier(identifier)

    job
  end

  defp load_jobs(redis_key, identifier) do
    []
  end

  defp default_identifier, do: Toniq.Keepalive.identifier()
end
