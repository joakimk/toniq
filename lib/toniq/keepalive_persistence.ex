defmodule Toniq.KeepalivePersistence do
  def register_vm(identifier, scope \\ default_scope) do
    redis_query(["SADD", registered_vms_key(scope), identifier])
  end

  def update_alive_key(identifier, keepalive_expiration, scope \\ default_scope) do
    # Logger.log(:debug, "Updating keepalive for #{state.identifier} #{inspect(debug_info)}")
    redis_query(["PSETEX", alive_key(scope, identifier), keepalive_expiration, debug_info])
  end

  def registered_vms(scope \\ default_scope) do
    redis_query(["SMEMBERS", registered_vms_key(scope)])
  end

  def alive_vm_debug_info(identifier, scope \\ default_scope) do
    redis_query(["GET", alive_key(scope, identifier)])
  end

  # Added so we could use it to default scope further out when we want to allow custom persistance scopes in testing.
  def default_scope, do: Application.get_env(:toniq, :redis_key_prefix)

  defp redis_query(query) do
    :toniq_redis
    |> Process.whereis
    |> Exredis.query(query)
  end

  # This is not a API any production code should rely upon, but could be useful
  # info when debugging or to verify things in tests.
  defp debug_info, do: %{ system_pid: System.get_pid, last_updated_at: :os.system_time }

  defp alive_key(scope, identifier), do: "#{scope}:alive_vms:#{identifier}"
  defp registered_vms_key(scope),    do: "#{scope}:registered_vms"
end
