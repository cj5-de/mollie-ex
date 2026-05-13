defmodule MollieEx.MixProject do
  use Mix.Project

  @version "0.0.1"
  @source_url "https://github.com/cj5-de/mollie-ex"

  def project do
    [
      app: :mollie_ex,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: @source_url,
      aliases: aliases(),
      deps: [
        {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        precommit: :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Community driven Elixir SDK for the Mollie API."
  end

  defp package do
    [
      name: "mollie_ex",
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp aliases do
    [
      precommit: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test",
        "credo --strict"
      ]
    ]
  end
end
