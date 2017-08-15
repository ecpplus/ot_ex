defmodule OT.Text.Operation do
  @moduledoc """
  A list of components that iterates over and/or modifies a piece of text
  """

  alias OT.Text.Component

  @typedoc """
  An operation, which is a list consisting of `t:OT.Text.Component.retain/0`,
  `t:OT.Text.Component.insert/0`, and `t:OT.Text.Component.delete/0` components
  """
  @type t :: [Component.t]

  @doc """
  Append a component to an operation.

  ## Example

      iex> OT.Text.Operation.append([%{i: [98, 99, 100]}], %{i: [198, 199, 200]})
      [%{i: [98, 99, 100, 198, 199, 200]}]
  """
  @spec append(t, Component.t) :: t
  def append([], comp), do: [comp]
  def append(op, comp) do
    last_component = List.last(op)

    if Component.no_op?(comp) do
      op
    else
      op
      |> Enum.slice(0..-2)
      |> Kernel.++(Component.join(last_component, comp))
    end
  end

  @doc """
  Invert an operation.

  ## Example

      iex> OT.Text.Operation.invert([4, %{i: [98, 99, 100]}])
      [-4, -3]
  """
  @spec invert(t) :: t
  def invert(op), do: Enum.map(op, &Component.invert/1)

  @doc """
  Join two operations into a single operation.

  ## Example

      iex> OT.Text.Operation.join([3, %{i: [98, 99, 100]}], [%{i: [198, 199, 200]}, 4])
      [3, %{i: [98, 99, 100, 198, 199, 200]}, 4]
  """
  @spec join(t, t) :: t
  def join([], op_b), do: op_b
  def join(op_a, []), do: op_a

  def join(op_a, op_b) do
    op_a
    |> append(hd(op_b))
    |> Kernel.++(tl(op_b))
  end

  require Logger

  @doc false
  @spec random(OT.Text.datum) :: t
  def random(text) do
    Logger.debug("random : #{inspect text}")
    text
    |> do_random
    |> Enum.reverse
  end

  @spec do_random([Integer.t], t) :: t

  defp do_random(text, op \\ [])

  defp do_random([], op), do: op

  defp do_random(text, op) do
    split_index = :rand.uniform(length(text) + 1) - 1
    # {chunk, new_text} = String.split_at(text, split_index)
    chunk    = Enum.slice(text, 0..split_index-1)
    new_text = Enum.slice(text, split_index..-1)
    comp = Component.random(chunk)
    Logger.debug("split_index: #{split_index}, chunk: #{inspect chunk}, new_text: #{inspect new_text}, op: #{inspect [comp | op ]}")
    Logger.debug("comp : #{inspect comp}")

    if Component.type(comp) == :insert do
      # Logger.debug("chunk: #{inspect chunk}, text: #{inspect text}")
      Logger.debug("insert")
      do_random(text, [comp | op])
    else
      # Logger.debug("chunk: #{inspect chunk}, new_text: #{inspect new_text}")
      Logger.debug("retain or delete")
      do_random(new_text, [comp | op])
    end
  end
end
