defmodule Toniq.Job do
  # NOTE: If the format changes: add migration code for older formats
  @job_format_version 1

  alias Toniq.Job

  defstruct [
    :id,
    :worker,
    :arguments,
    :version,
    :options,
    :vm,
    :error
  ]

  def new(worker_module, arguments, options \\ nil) do
    %Job{
      worker: worker_module,
      arguments: arguments,
      version: @job_format_version,
      options: add_delay(options)
    }
  end

  def set_id(job, id), do: %{job | id: id}

  def add_vm_identifier(job, identifier), do: %{job | vm: identifier}

  def set_error(job, error), do: %{job | error: error}

  def migrate(job), do: migrate_v0_jobs_to_v1(job)

  # Convert from the pre-1.0 format. Replace this with the migration from 1 to 2 when you add job_format_version 2. We keep it to be able to test format migration.
  defp migrate_v0_jobs_to_v1(map) do
    if Map.has_key?(map, :version) do
      {:unchanged, map}
    else
      v1 =
        %{
          id: map.id,
          worker: map.worker,
          arguments: map.opts,
          version: @job_format_version
        }
        |> add_error_if_present_in_source_data(map)

      {:changed, map, v1}
    end
  end

  defp add_error_if_present_in_source_data(v1, map) do
    if Map.get(map, :error) do
      Map.put(v1, :error, map.error)
    else
      v1
    end
  end

  defp add_delay(nil), do: nil

  defp add_delay(options) do
    options
    |> Keyword.get(:delay_for)
    |> case do
      nil -> options
      delay -> Keyword.put(options, :delayed_until, delay |> to_expiry)
    end
  end

  defp to_expiry(:infinity), do: :infinity
  defp to_expiry(delay), do: :os.system_time(:milli_seconds) + delay
end
