defmodule Exqueue.PubSub do
  def publish do
    Process.whereis(:publish_redis)
    |> Exredis.query([ "publish", "job_added", "1" ])
  end

  def subscribe do
    subscribing_process = self

    spawn_link fn ->
      :eredis_sub.controlling_process(subscribe_redis)
      :eredis_sub.subscribe(subscribe_redis, ['job_added'])
      receiver(subscribing_process)
    end
  end

  defp receiver(subscribing_process) do
    receive do
      {:message, "job_added", _, _} ->
        send subscribing_process, :job_added
      _other ->
        nil
    end

    :eredis_sub.ack_message(subscribe_redis)

    receiver(subscribing_process)
  end

  defp subscribe_redis do
    Process.whereis(:subscribe_redis)
  end
end
