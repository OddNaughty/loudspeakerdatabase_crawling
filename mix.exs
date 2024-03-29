defmodule LoudspeakerCrawling.MixProject do
  use Mix.Project

  def project do
    [
      app: :loudspeaker_crawling,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:meeseeks, "~> 0.17.0"},
      {:httpoison, "~> 2.1.0"},
      {:nimble_csv, "~> 1.2.0"}
    ]
  end
end
