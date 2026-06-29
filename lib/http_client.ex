defmodule ConcurrencyTest.HttpClient do
  @moduledoc "Thin Req wrapper. Returns `{:ok, status, latency_ms}` or `{:error, reason, latency_ms}`."

  @doc """
  Sends an HTTP request and measures latency.

  Returns `{:ok, status_code, latency_ms}` on success or `{:error, reason, latency_ms}` on failure.
  The body is JSON-encoded when non-empty.
  """
  @spec request(String.t(), String.t(), map(), map(), pos_integer()) ::
          {:ok, non_neg_integer(), non_neg_integer()} | {:error, term(), non_neg_integer()}
  def request(method, url, headers, body, timeout) do
    method_atom = method |> String.downcase() |> String.to_atom()
    headers_list = Enum.map(headers, fn {k, v} -> {to_string(k), to_string(v)} end)

    opts =
      [
        method: method_atom,
        url: url,
        headers: headers_list,
        finch: ConcurrencyTest.Finch,
        receive_timeout: timeout,
        retry: false
      ]
      |> maybe_add_body(body)

    t0 = System.monotonic_time(:millisecond)

    case Req.request(opts) do
      {:ok, %{status: status}} -> {:ok, status, elapsed(t0)}
      {:error, reason} -> {:error, reason, elapsed(t0)}
    end
  end

  defp maybe_add_body(opts, body) when is_map(body) and map_size(body) > 0,
    do: Keyword.put(opts, :json, body)

  defp maybe_add_body(opts, _), do: opts

  defp elapsed(t0), do: System.monotonic_time(:millisecond) - t0
end
