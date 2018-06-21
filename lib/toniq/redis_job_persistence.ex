defmodule Toniq.RedisJobPersistence do
  use Toniq.JobPersistence, adapter: Toniq.RedisAdapter
end
