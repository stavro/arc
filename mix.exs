defmodule Arc.Mixfile do
  use Mix.Project

  @version "0.6.0-rc2"

  def project do
    [app: :arc,
     version: @version,
     elixir: "~> 1.0",
     deps: deps,

    # Hex
     description: description,
     package: package]
  end

  defp description do
    """
    Flexible file upload and attachment library for Elixir.
    """
  end

  defp package do
    [maintainers: ["Sean Stavropoulos"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/stavro/arc"},
     files: ~w(mix.exs README.md CHANGELOG.md lib)]
  end

  def application do
    [
      applications: [
        :logger
      ] ++ applications(Mix.env)
    ]
  end

  def applications(:test), do: [:ex_aws, :poison, :hackney]
  def applications(_), do: []

  defp deps do
    [
      {:ex_aws, "~> 1.0.0-rc.2", optional: true},
      {:mock, "~> 0.1.1", only: :test},
      {:ex_doc, "~> 0.14", only: :dev},

      # If using Amazon S3:
      {:hackney, "~> 1.5", optional: true},
      {:poison, "~> 2.0", optional: true},
      {:sweet_xml, "~> 0.5", optional: true}
    ]
  end
end
