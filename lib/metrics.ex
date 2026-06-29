defmodule ConcurrencyTest.Metrics do
  @moduledoc "GenServer that accumulates request metrics for a single test run."

  use GenServer

  defstruct total: 0,
            success: 0,
            failure: 0,
            status_codes: %{},
            latencies: [],
            started_at: nil,
            finished_at: nil

  @type t :: %__MODULE__{
          total: non_neg_integer(),
          success: non_neg_integer(),
          failure: non_neg_integer(),
          status_codes: %{non_neg_integer() => non_neg_integer()},
          latencies: [non_neg_integer()],
          started_at: integer() | nil,
          finished_at: integer() | nil
        }

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)

  @doc "Marks the start of a test run."
  @spec start_run() :: :ok
  def start_run, do: GenServer.cast(__MODULE__, :start_run)

  @doc "Records the result of a single request."
  @spec record({:ok, non_neg_integer(), non_neg_integer()} | {:error, term(), non_neg_integer()}) ::
          :ok
  def record(result), do: GenServer.cast(__MODULE__, {:record, result})

  @doc "Marks the end of a test run and returns the accumulated metrics."
  @spec finish_run() :: t()
  def finish_run, do: GenServer.call(__MODULE__, :finish_run)

  @impl GenServer
  def init(state), do: {:ok, state}

  @impl GenServer
  def handle_cast(:start_run, _state) do
    {:noreply, %__MODULE__{started_at: System.monotonic_time(:millisecond)}}
  end

  def handle_cast({:record, {:ok, status, latency}}, state) do
    codes = Map.update(state.status_codes, status, 1, &(&1 + 1))

    {:noreply,
     %{state | total: state.total + 1, success: state.success + 1, status_codes: codes, latencies: [latency | state.latencies]}}
  end

  def handle_cast({:record, {:error, _reason, latency}}, state) do
    {:noreply,
     %{state | total: state.total + 1, failure: state.failure + 1, latencies: [latency | state.latencies]}}
  end

  @impl GenServer
  def handle_call(:finish_run, _from, state) do
    final = %{state | finished_at: System.monotonic_time(:millisecond)}
    {:reply, final, final}
  end
end
