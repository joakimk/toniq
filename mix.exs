defmodule Toniq.Mixfile do
  use Mix.Project

  def project do
    [
      app: :toniq,
      version: "1.2.3",
      elixir: "~> 1.0",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :elixir_uuid, :exredis], mod: {Toniq, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:exredis, ">= 0.1.1"},
      {:elixir_uuid, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:mix_test_watch, "~> 0.5", only: :dev, runtime: false},
      {:retry, "~> 0.5.0", only: :test}
    ]
  end

  defp description do
    """
    Simple and reliable background job processing library for Elixir.

    Has persistence, retries, delayed jobs, concurrency limiting, error handling and is heroku friendly.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md"],
      maintainers: ["Joakim Kolsjö"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/joakimk/toniq"}
    ]
  end
end
