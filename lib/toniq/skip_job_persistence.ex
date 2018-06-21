defmodule Toniq.SkipJobPersistence do
  use Toniq.JobPersistence, adapter: Toniq.SkipAdapter
end
