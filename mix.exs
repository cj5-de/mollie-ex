defmodule MollieEx.MixProject do
  use Mix.Project

  @version "0.0.1"
  @source_url "https://github.com/cj5-de/mollie-ex"

  def project do
    [
      app: :mollie_ex,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: @source_url,
      deps: []
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
end
