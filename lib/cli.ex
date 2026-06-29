defmodule ConcurrencyTest.CLI do
  @moduledoc "Parses command-line arguments and orchestrates the run."

  alias ConcurrencyTest.{Config, Report, Runner}

  @doc "Entry point. Accepts argv-style argument list."
  @spec main([String.t()]) :: :ok
  def main([path]) do
    ensure_started()

    case Config.load(path) do
      {:ok, scenario} ->
        metrics = Runner.run(scenario)
        Report.print(scenario.name, scenario.run.requests, scenario.run.concurrency, metrics)

      {:error, reason} ->
        IO.puts(:stderr, "Error: #{reason}")
        System.halt(1)
    end
  end

  def main(_) do
    IO.puts("""
    concurrency-test — concurrent HTTP scenario runner

    Usage:
      concurrency-test <scenario.yml>

    Example:
      concurrency-test transfer.yml
    """)

    System.halt(1)
  end

  # When run as an escript the OTP application is not started automatically.
  # Start only what the run needs; in a release these are already supervised.
  defp ensure_started do
    unless Process.whereis(ConcurrencyTest.Metrics) do
      Application.ensure_all_started(:logger)
      Application.ensure_all_started(:finch)
      Finch.start_link(name: ConcurrencyTest.Finch)
      ConcurrencyTest.Metrics.start_link([])
    end
  end
end
