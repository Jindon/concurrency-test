defmodule ConcurrencyTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :concurrency_test,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {ConcurrencyTest, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:finch, "~> 0.18"},
      {:yaml_elixir, "~> 2.9"},
      {:jason, "~> 1.4"},
      {:burrito, "~> 1.0"}
    ]
  end

  # app: nil — escript does not start the OTP application; CLI.main starts deps manually.
  defp escript do
    [main_module: ConcurrencyTest.CLI, app: nil]
  end

  defp releases do
    [
      concurrency_test: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos_arm: [os: :darwin, cpu: :aarch64],
            macos: [os: :darwin, cpu: :x86_64],
            linux: [os: :linux, cpu: :x86_64],
            windows: [os: :windows, cpu: :x86_64]
          ]
        ]
      ]
    ]
  end
end
