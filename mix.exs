defmodule Stow.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "Composable data pipeline with middleware and adapters support."

  def project do
    [
      app: :stow,
      version: @version,
      description: @description,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets, :public_key, :crypto]
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.15"},

      # for tests
      {:bypass, "~> 2.1", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:hammox, "~> 0.7", only: :test}
    ]
  end
end
