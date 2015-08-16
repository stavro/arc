defmodule Arc.Mixfile do
  use Mix.Project

  @version "0.1.1"

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
    [contributors: ["Sean Stavropoulos"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/stavro/arc"},
     files: ~w(mix.exs README.md CHANGELOG.md lib)]
  end
  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger]]
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
      {:erlcloud, "~> 0.9.0"},
      {:mock, "~> 0.1.1", only: :test}
    ]
  end
end
