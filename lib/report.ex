defmodule ConcurrencyTest.Report do
  @moduledoc "Formats and prints the metrics summary to stdout."

  alias ConcurrencyTest.Metrics

  @doc "Prints the run summary."
  @spec print(String.t(), pos_integer(), pos_integer(), Metrics.t()) :: :ok
  def print(name, requests, concurrency, metrics) do
    latencies = Enum.sort(metrics.latencies)
    duration_ms = (metrics.finished_at || 0) - (metrics.started_at || 0)
    rps = if duration_ms > 0, do: round(metrics.total * 1_000 / duration_ms), else: 0

    IO.puts("""

    #{name}

    Requests:      #{requests}
    Concurrency:   #{concurrency}

    Success:       #{metrics.success}
    Failure:       #{metrics.failure}

    Status Codes

    #{format_status_codes(metrics.status_codes)}
    Average : #{avg(latencies)} ms
    Min     : #{min_val(latencies)} ms
    Max     : #{max_val(latencies)} ms
    P95     : #{percentile(latencies, 95)} ms
    P99     : #{percentile(latencies, 99)} ms

    RPS     : #{rps}
    """)
  end

  @doc "Calculates the nth percentile of a pre-sorted list."
  @spec percentile([number()], 1..99) :: number()
  def percentile([], _p), do: 0

  def percentile(sorted, p) do
    idx = ceil(length(sorted) * p / 100) - 1
    Enum.at(sorted, min(idx, length(sorted) - 1))
  end

  defp format_status_codes(codes) when map_size(codes) == 0, do: "(none)\n"

  defp format_status_codes(codes) do
    codes
    |> Enum.sort()
    |> Enum.map_join("\n", fn {code, count} -> "#{code} : #{count}" end)
    |> Kernel.<>("\n")
  end

  defp avg([]), do: 0
  defp avg(sorted), do: round(Enum.sum(sorted) / length(sorted))

  defp min_val([]), do: 0
  defp min_val([h | _]), do: h

  defp max_val([]), do: 0
  defp max_val(sorted), do: List.last(sorted)
end
