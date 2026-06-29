defmodule ConcurrencyTest.Config do
  @moduledoc "Loads and validates a scenario YAML file into typed structs."

  defmodule RunConfig do
    @moduledoc false
    @enforce_keys [:requests, :concurrency, :timeout]
    defstruct [:requests, :concurrency, :timeout]

    @type t :: %__MODULE__{
            requests: pos_integer(),
            concurrency: pos_integer(),
            timeout: pos_integer()
          }
  end

  defmodule RequestConfig do
    @moduledoc false
    @enforce_keys [:method, :url]
    defstruct [:method, :url]

    @type t :: %__MODULE__{method: String.t(), url: String.t()}
  end

  defmodule Scenario do
    @moduledoc false
    @enforce_keys [:name, :run, :request]
    defstruct [:name, :run, :request, headers: %{}, body: %{}]

    @type t :: %__MODULE__{
            name: String.t(),
            run: RunConfig.t(),
            request: RequestConfig.t(),
            headers: map(),
            body: map()
          }
  end

  @valid_methods ~w(GET POST PUT PATCH DELETE HEAD OPTIONS)

  @doc "Loads a YAML scenario file. Returns `{:ok, Scenario.t()}` or `{:error, reason}`."
  @spec load(String.t()) :: {:ok, Scenario.t()} | {:error, String.t()}
  def load(path) do
    unless File.exists?(path) do
      {:error, "File not found: #{path}"}
    else
      case YamlElixir.read_from_file(path) do
        {:ok, raw} -> parse(raw)
        {:error, reason} -> {:error, "Failed to parse YAML: #{inspect(reason)}"}
      end
    end
  end

  @doc "Parses a scenario from an already-loaded map. Useful for testing."
  @spec load_from_map(map()) :: {:ok, Scenario.t()} | {:error, String.t()}
  def load_from_map(raw) when is_map(raw), do: parse(raw)

  defp parse(raw) do
    with {:ok, run} <- parse_run(raw["run"]),
         {:ok, request} <- parse_request(raw["request"]) do
      {:ok,
       %Scenario{
         name: raw["name"] || "Unnamed Scenario",
         run: run,
         request: request,
         headers: raw["headers"] || %{},
         body: raw["body"] || %{}
       }}
    end
  end

  defp parse_run(nil), do: {:error, "Missing required field: run"}

  defp parse_run(run) do
    with {:ok, requests} <- required_pos_integer(run, "requests"),
         {:ok, concurrency} <- required_pos_integer(run, "concurrency"),
         {:ok, timeout} <- required_pos_integer(run, "timeout") do
      {:ok, %RunConfig{requests: requests, concurrency: concurrency, timeout: timeout}}
    end
  end

  defp parse_request(nil), do: {:error, "Missing required field: request"}

  defp parse_request(req) do
    method = String.upcase(req["method"] || "GET")
    url = req["url"]

    cond do
      is_nil(url) or url == "" -> {:error, "Missing required field: request.url"}
      method not in @valid_methods -> {:error, "Invalid HTTP method: #{method}"}
      true -> {:ok, %RequestConfig{method: method, url: url}}
    end
  end

  defp required_pos_integer(map, key) do
    case map[key] do
      nil -> {:error, "Missing required field: run.#{key}"}
      val when is_integer(val) and val > 0 -> {:ok, val}
      _ -> {:error, "run.#{key} must be a positive integer"}
    end
  end
end
