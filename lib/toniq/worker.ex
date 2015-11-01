defmodule Toniq.Worker do
  defmacro __using__(_opts \\ []) do
    quote do
      # Delegate to perform without arguments when arguments are [],
      # you can define a perform with an argument to override this.
      def perform([]) do
        perform
      end

      defoverridable [perform: 1]
    end
  end
end
