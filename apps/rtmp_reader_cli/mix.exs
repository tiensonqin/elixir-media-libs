defmodule RtmpReaderCli.Mixfile do
  use Mix.Project

  def project do
    [
      app: :rtmp_reader_cli,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [
        main_module: RtmpReaderCli,
        name: "rtmp_reader_cli.escript"
      ]
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:rtmp, in_umbrella: true}]
  end
end
