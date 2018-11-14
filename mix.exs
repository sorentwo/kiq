defmodule Kiq.MixProject do
  use Mix.Project

  @version "0.4.0"

  def project do
    [
      app: :kiq,
      version: @version,
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      package: package(),
      description: """
      Robust job queue compatible with Sidekiq Enterprise, powered by GenStage and Redis
      """,

      # Dialyzer
      dialyzer: [
        plt_add_apps: [:eex, :ex_unit, :mix],
        flags: [:error_handling, :race_conditions, :underspecs]
      ],

      # Docs
      name: "Kiq",
      docs: [
        main: "Kiq",
        source_ref: "v#{@version}",
        source_url: "https://github.com/sorentwo/kiq",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  def package do
    [
      maintainers: ["Parker Selbert"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/sorentwo/kiq"}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.1"},
      {:gen_stage, "~> 0.14"},
      {:nimble_parsec, "~> 0.5"},
      {:redix, "~> 0.9"},
      {:telemetry, "~> 0.2"},
      {:benchee, "~> 0.13", only: [:dev], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 0.4", only: [:test]}
    ]
  end
end
