defmodule Annotations.Mixfile do
  use Mix.Project

  def project do
    [app: :annotations,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     package: [
      maintainers: ["Paul Balomiri", "paul.balomiri@gmail.com"],
      description: "String Annotation Package",
      licenses: ["WTFPL"],
      links: %{"GitHub" => "https://github.com/openapi-ro/annotations"}
     ]

    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
    ] ++ priv_deps [
      "openapi-ro": [
        :rangex
      ]
    ]
  end
  def priv_deps(packages_by_org) do
    packages_by_org
    |>Enum.flat_map( fn {org, packages} ->
      Enum.map(packages, &(priv_dep(Mix.env, to_string(org), &1)))
    end)
  end
  def priv_dep(:prod, org, package ),
    do: {package, git: "git@github.com:#{org}/#{package}.git"}
  def priv_dep(:test, _org, package ),
    do: {package, path: "../#{package}", env: :dev}
  def priv_dep(env, _org, package ),
    do: {package, path: "../#{package}", env: env}
end
