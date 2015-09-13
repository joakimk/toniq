# This is used to test failover by running multiple elixir vms and
# checking what happens in different failure scenarios.
#
# The code must exist in both client and server processes, so it's
# compiled into toniq, but only in the test environment.

if Mix.env == :test do
  defmodule Toniq.FailoverTestHelper do
    defmodule TestWorker do
    end

    def spawn_and_connect(name) do
      Node.start(:test, :shortnames)

      spawn_link fn ->
        System.cmd "elixir", [ "--sname", name, "--no-halt", "-S", "mix" ], env: [ {"MIX_ENV", "test"} ]
      end

      wait_for_connection(name)
    end

    def add_job(name) do
      run_on name, fn ->
        Toniq.Persistence.store_job(TestWorker, some: "data")
      end
    end

    def get_state(name) do
      run_on name, fn ->
        %{ jobs: Toniq.Persistence.jobs, system_pid: System.get_pid }
      end
    end

    def halt(name) do
      Node.spawn node_name(name), fn -> System.halt(0) end
    end

    defp run_on(name, function) do
      caller = self

      Node.spawn_link node_name(name), fn ->
        send caller, function.()
      end

      receive do
        result ->
          result
      end
    end

    defp wait_for_connection(name) do
      unless Node.connect(node_name(name)) do
        :timer.sleep 100
        wait_for_connection(name)
      end

      # TODO: figure out how to reliably detect when the node is ready
      :timer.sleep 500
    end

    defp node_name(name) do
      {:ok, hostname} = :inet.gethostname
      :"#{name}@#{hostname}"
    end
  end
end
