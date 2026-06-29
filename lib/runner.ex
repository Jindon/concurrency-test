defmodule ConcurrencyTest.Runner do
  @moduledoc "Drives concurrent requests using `Task.async_stream` and collects metrics."

  alias ConcurrencyTest.{Config.Scenario, Metrics, Worker}

  @doc "Executes all requests in the scenario. Returns final metrics."
  @spec run(Scenario.t()) :: Metrics.t()
  def run(%Scenario{} = scenario) do
    Metrics.start_run()

    1..scenario.run.requests
    |> Task.async_stream(
      fn _ -> Worker.execute(scenario) end,
      max_concurrency: scenario.run.concurrency,
      timeout: scenario.run.timeout + 1_000,
      on_timeout: :kill_task
    )
    |> Stream.each(fn
      {:ok, result} -> Metrics.record(result)
      {:exit, _} -> Metrics.record({:error, :timeout, scenario.run.timeout})
    end)
    |> Stream.run()

    Metrics.finish_run()
  end
end
