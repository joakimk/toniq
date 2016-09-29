defmodule Toniq.Job do
  # NOTE: If the format changes: add migration code for older formats
  @job_format_version 1

  def build(id, worker_module, arguments, options \\ []) do
    %{id: id, worker: worker_module, arguments: arguments, version: @job_format_version}
    |> add_delay(options)
  end

  def migrate(job), do: migrate_v0_jobs_to_v1(job)

  # Convert from the pre-1.0 format. Don't need to support this much past januari 2016.
  defp migrate_v0_jobs_to_v1(map) do
    if Map.has_key?(map, :version) do
      {:unchanged, map}
    else
      v1 = %{
        id: map.id,
        worker: map.worker,
        arguments: map.opts,
        version: @job_format_version,
      }

      if Map.get(map, :error) do
        v1 = Map.put(v1, :error, map.error)
      end

      {:changed, map, v1}
    end
  end

  defp add_delay(job, options) do
    options
    |> Keyword.get(:delay_for)
    |> case do
      nil   -> job
      delay -> job |> Map.put(:delayed_until, delay |> to_expiry)
    end
  end

  defp to_expiry(delay), do: :os.system_time(:milli_seconds) + delay
end
