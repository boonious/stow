defmodule Stow.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "Composable ETL data plugs and pipelines that fit various process architectures."

  def project do
    [
      app: :stow,
      version: @version,
      description: @description,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [ci: :test],
      aliases: [
        ci: ["format", "credo", "dialyzer", "test"]
      ]
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
      {:castore, "~> 1.0"},

      # for tests
      {:bypass, "~> 2.1", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:hammox, "~> 0.7", only: :test}
    ]
  end
end
