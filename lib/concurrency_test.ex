defmodule ConcurrencyTest do
  @moduledoc "OTP Application. Starts infrastructure and, in prod, the CLI."

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      {Finch, name: ConcurrencyTest.Finch},
      ConcurrencyTest.Metrics
    ]

    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)

    unless Application.get_env(:concurrency_test, :skip_cli, false) do
      Task.start(fn ->
        argv = Burrito.Util.Args.argv()
        ConcurrencyTest.CLI.main(argv)
        System.halt(0)
      end)
    end

    {:ok, sup}
  end
end
