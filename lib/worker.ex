defmodule ConcurrencyTest.Worker do
  @moduledoc "Renders templates and fires a single HTTP request for a given scenario."

  alias ConcurrencyTest.{Config.Scenario, HttpClient, Template}

  @doc "Renders per-request templates then sends the HTTP request."
  @spec execute(Scenario.t()) ::
          {:ok, non_neg_integer(), non_neg_integer()} | {:error, term(), non_neg_integer()}
  def execute(%Scenario{} = scenario) do
    headers = Template.render(scenario.headers)
    body = Template.render(scenario.body)

    HttpClient.request(
      scenario.request.method,
      scenario.request.url,
      headers,
      body,
      scenario.run.timeout
    )
  end
end
