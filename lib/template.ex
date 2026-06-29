defmodule ConcurrencyTest.Template do
  @moduledoc "Recursive template renderer. Traverses maps, lists, and strings, replacing `{{placeholder}}` tokens."

  import Bitwise

  @doc "Renders all `{{placeholder}}` tokens in nested data. Each `{{uuid}}` generates a fresh UUID."
  @spec render(term()) :: term()
  def render(map) when is_map(map), do: Map.new(map, fn {k, v} -> {k, render(v)} end)
  def render(list) when is_list(list), do: Enum.map(list, &render/1)

  def render(string) when is_binary(string) do
    Regex.replace(~r/\{\{(\w+)\}\}/, string, fn _, name -> resolve(name) end)
  end

  def render(other), do: other

  defp resolve("uuid"), do: uuid4()
  # ponytail: unknown placeholders pass through so new tokens can be added incrementally
  defp resolve(name), do: "{{#{name}}}"

  defp uuid4 do
    <<b1::32, b2::16, b3::16, b4::16, b5::48>> = :crypto.strong_rand_bytes(16)
    b3v = (b3 &&& 0x0FFF) ||| 0x4000
    b4v = (b4 &&& 0x3FFF) ||| 0x8000

    [hex(b1, 8), hex(b2, 4), hex(b3v, 4), hex(b4v, 4), hex(b5, 12)]
    |> Enum.join("-")
  end

  defp hex(n, len),
    do: n |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(len, "0")
end
