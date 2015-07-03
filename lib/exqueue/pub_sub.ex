defmodule Exqueue.PubSub do
  def publish do
    Process.whereis(:redis)
    |> Exredis.query(["publish", redis_key, "1"])
  end

  def subscribe do
    subscribing_process = self

    # NOTE: Don't use spawn_link, there is some problem with :eredis_sub.controlling_process that causes
    #       the entire app to shutdown instead of the process tree being restarted. See the README todo list.
    spawn fn ->
      :eredis_sub.controlling_process(subscribe_redis)
      :eredis_sub.subscribe(subscribe_redis, [String.to_char_list(redis_key)])
      receiver(subscribing_process)
    end
  end

  defp receiver(subscribing_process) do
    receive do
      {:message, redis_key, _, _} ->
        send subscribing_process, :job_added
      _other ->
        nil
    end

    :eredis_sub.ack_message(subscribe_redis)

    receiver(subscribing_process)
  end

  defp redis_key do
    "exqueue_job_added"
  end

  defp subscribe_redis do
    Process.whereis(:subscribe_redis)
  end
end
