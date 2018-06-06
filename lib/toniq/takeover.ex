defmodule Toniq.Takeover do
  @moduledoc """
  Checks redis for orphaned jobs from other vms and moves them into a incoming
  jobs list.

  This list is then imported by Toniq.JobImporter.
  """

  use GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, %{keepalive_name: Toniq.Keepalive}, name: __MODULE__)
  end

  def init(state) do
    {:ok, _} = :timer.send_interval(takeover_interval(), :check_takeover)
    {:ok, state}
  end

  def handle_info(:check_takeover, state) do
    registered_vms()
    |> select_first_missing
    |> handle_missing_vm(state)

    {:noreply, state}
  end

  defp registered_vms do
    Toniq.JobPersistence.adapter().registered_vms()
  end

  defp select_first_missing(vms) do
    vms
    |> Enum.find(fn identifier -> missing?(identifier) end)
  end

  defp missing?(identifier) do
    !Toniq.JobPersistence.adapter().alive?(identifier)
  end

  defp handle_missing_vm(nil, _state), do: nil

  defp handle_missing_vm(identifier, state) do
    Logger.log(:info, "#{__MODULE__}: Taking over all jobs from missing vm #{identifier}")

    Toniq.JobPersistence.adapter().takeover_jobs(
      identifier,
      Toniq.Keepalive.identifier(state.keepalive_name)
    )

    Toniq.DelayedJobTracker.reload_job_list()
  end

  defp takeover_interval, do: Application.get_env(:toniq, :takeover_interval)
end
