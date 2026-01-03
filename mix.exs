defmodule ZoiPhoenixSwagger.MixProject do
  use Mix.Project

  def project do
    [
      app: :zoi_phoenix_swagger,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: "https://github.com/nirev/zoi_phoenix_swagger"
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
      {:phoenix_swagger, "~> 0.8"},
      {:zoi, "~> 0.1"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Integration library between Zoi and Phoenix Swagger for automatic parameter validation and OpenAPI documentation generation."
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/nirev/zoi_phoenix_swagger"}
    ]
  end
end
