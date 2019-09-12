defmodule Amf0.Mixfile do
  use Mix.Project

  def project do
    [
      app: :amf0,
      version: "1.0.1",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.2",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:ex_doc, "~> 0.14", only: :dev}]
  end

  defp package do
    [
      name: :eml_amf0,
      maintainers: ["Matthew Shapiro"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/KallDrexx/elixir-media-libs/tree/master/apps/amf0"}
    ]
  end

  defp description do
    "Provides functions to serialize and deserialize data encoded in the AMF0 data format"
  end
end
