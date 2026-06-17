defmodule MollieEx.MixProject do
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/cj5-de/mollie-ex"

  def project do
    [
      app: :mollie_ex,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: @source_url,
      docs: docs(),
      aliases: aliases(),
      deps: [
        {:req, "~> 0.5"},
        {:finch, "~> 0.22"},
        {:jason, "~> 1.4"},
        {:telemetry, "~> 1.4"},
        {:bypass, "~> 2.1", only: :test},
        {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
        {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
        {:ex_doc, "~> 0.40.3", only: :dev, runtime: false}
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

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

  defp docs do
    [
      main: "overview",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "guides/overview.md",
        "guides/getting-started.md",
        "guides/resources.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        Guides: [
          "guides/overview.md",
          "guides/getting-started.md",
          "guides/resources.md"
        ],
        Reference: [
          "CHANGELOG.md",
          "LICENSE"
        ]
      ],
      groups_for_modules: [
        Client: [
          MollieEx,
          MollieEx.Client,
          MollieEx.Error
        ],
        Resources: [
          MollieEx.Payments,
          MollieEx.Refunds,
          MollieEx.Captures,
          MollieEx.Chargebacks,
          MollieEx.PaymentRoutes,
          MollieEx.PaymentLinks,
          MollieEx.Customers,
          MollieEx.Methods,
          MollieEx.Mandates,
          MollieEx.Subscriptions,
          MollieEx.Profiles,
          MollieEx.Permissions,
          MollieEx.Organizations,
          MollieEx.Onboarding,
          MollieEx.Capabilities,
          MollieEx.Clients,
          MollieEx.ClientLinks
        ],
        Structs: [
          MollieEx.Payment,
          MollieEx.Refund,
          MollieEx.Capture,
          MollieEx.Chargeback,
          MollieEx.Route,
          MollieEx.PaymentLink,
          MollieEx.Customer,
          MollieEx.Method,
          MollieEx.Mandate,
          MollieEx.Subscription,
          MollieEx.Profile,
          MollieEx.Permission,
          MollieEx.Organization,
          MollieEx.Partner,
          MollieEx.OnboardingStatus,
          MollieEx.Capability,
          MollieEx.ClientResource,
          MollieEx.ClientLink,
          MollieEx.List
        ],
        Types: [
          MollieEx.Types.Money,
          MollieEx.Types.Link
        ]
      ]
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
