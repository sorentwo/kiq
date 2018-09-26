defmodule Kiq.MixProject do
  use Mix.Project

  @version "0.2.0"

  @repo_url "https://github.com/sorentwo/kiq"

  def project do
    [
      app: :kiq,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      package: package(),
      description: """
      Robust job queue compatible with Sidekiq Enterprise, powered by GenStage and Redis
      """,

      # Dialyzer
      dialyzer: [
        plt_add_apps: [:ex_unit],
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

  def package do
    [
      maintainers: ["Parker Selbert"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.1"},
      {:gen_stage, "~> 0.14"},
      {:redix, "~> 0.7"},
      {:benchee, "~> 0.13", only: [:dev], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19-rc", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 0.4", only: [:test]}
    ]
  end
end
