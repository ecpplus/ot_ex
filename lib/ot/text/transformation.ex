defmodule OT.Text.Transformation do
  require Logger
  @moduledoc """
  The transformation of two concurrent operations such that they satisfy the
  [TP1][tp1] property of operational transformation.

  [tp1]: https://en.wikipedia.org/wiki/Operational_transformation#Convergence_properties
  """

  alias OT.Text.{Component, Operation, Scanner}

  @doc """
  Transform an operation against another operation.

  Given an operation A that occurred at the same time as operation B against the
  same text state, transform the components of operation A such that the state
  of the text after applying operation A and then operation B is the same as
  after applying operation B and then the transformation of operation A against
  operation B:

  *S ○ Oa ○ transform(Ob, Oa) = S ○ Ob ○ transform(Oa, Ob)*

  This function also takes a third `side` argument that indicates which
  operation came later. This is important when deciding whether it is acceptable
  to break up insert components from one operation or the other.
  """
  @spec transform(Operation.t, Operation.t) :: [Operation.t]
  def transform(op_a, op_b, side) do
    {op_a, op_b}
    |> next
    |> do_transform(side)
  end

  defp transform_loop(_, _, nil, nil, operation1Prime, operation2Prime, _, _) do
    [operation1Prime, operation2Prime]
  end

  # op1 == :insert
  defp transform_loop(op1s, op2s, op1=%{i: _}, op2, operation1Prime, operation2Prime, op1_position, op2_position) do
    operation1Prime = List.insert_at(operation1Prime, -1, op1)
    operation2Prime = List.insert_at(operation2Prime, -1, Component.length(op1))
    op1_position = op1_position + 1
    op1 = Enum.at(op1s, op1_position)
    transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
  end

  # op2 == :insert
  defp transform_loop(op1s, op2s, op1, op2=%{i: _}, operation1Prime, operation2Prime, op1_position, op2_position) do
    operation1Prime = List.insert_at(operation1Prime, -1, Component.length(op2))
    operation2Prime = List.insert_at(operation2Prime, -1, op2)
    op2_position = op2_position + 1
    op2 = Enum.at(op2s, op2_position)
    transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
  end

  # op1: retain, op2: retain
  defp transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position) when is_integer(op1) and is_integer(op2) and 0 <= op1 and 0 <= op2 do
    [minl, op1, op2, op1_position, op2_position] = cond do
      Component.length(op1) > Component.length(op2) ->
        minl = op2
        op1  = op1 - op2
        op2_position = op2_position + 1
        op2 = Enum.at(op2s, op2_position)
        [minl, op1, op2, op1_position, op2_position]
      Component.length(op1) == Component.length(op2) ->
        minl = op2
        op1_position = op1_position + 1
        op2_position = op2_position + 1
        op1 = Enum.at(op1s, op1_position)
        op2 = Enum.at(op2s, op2_position)
        [minl, op1, op2, op1_position, op2_position]
      true ->
        minl = op1
        op2  = op2 - op1
        op1_position = op1_position + 1
        op1 = Enum.at(op1s, op1_position)
        [minl, op1, op2, op1_position, op2_position]
    end

    operation1Prime = List.insert_at(operation1Prime, -1, minl)
    operation2Prime = List.insert_at(operation2Prime, -1, minl)
    transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
  end

  # op1: delete, op2: delete
  defp transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position) when is_integer(op1) and is_integer(op2) and op1 < 0 and op2 < 0 do
    cond do
      Component.length(op1) > Component.length(op2) ->
        op1 = %{d: String.slice(op1.d, Component.length(op2)..-1)}
        op2_position = op2_position + 1
        op2 = Enum.at(op2s, op2_position)
        transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
      Component.length(op1) == Component.length(op2) ->
        op1_position = op1_position + 1
        op2_position = op2_position + 1
        op1 = Enum.at(op1s, op1_position)
        op2 = Enum.at(op2s, op2_position)
        transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
      true ->
        op2 = %{d: String.slice(op2.d, Component.length(op1)..-1)}
        op1_position = op1_position + 1
        op1 = Enum.at(op1s, op1_position)
        transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
    end
  end

  # op1: delete, op2: retain
  defp transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position) when is_integer(op1) and is_integer(op2) and op1 < 0 and 0 <= op2 do
    [minl, op1, op2, op1_position, op2_position] = cond do
      Component.length(op1) > Component.length(op2) ->
        minl = %{d: String.slice(op1.d, -Component.length(op2)..-1)}
        op1  = %{d: String.slice(op1.d, -(Component.length(op1) - Component.length(op2))..-1)}
        op2_position = op2_position + 1
        op2 = Enum.at(op2s, op2_position)
        [minl, op1, op2, op1_position, op2_position]
      Component.length(op1) == Component.length(op2) ->
        minl = op1
        op1_position = op1_position + 1
        op2_position = op2_position + 1
        op1 = Enum.at(op1s, op1_position)
        op2 = Enum.at(op2s, op2_position)
        [minl, op1, op2, op1_position, op2_position]
      true ->
        minl = op1
        op2  = op2 - Component.length(op1)
        op1_position = op1_position + 1
        op1 = Enum.at(op1s, op1_position)
        [minl, op1, op2, op1_position, op2_position]
    end
    operation1Prime = List.insert_at(operation1Prime, -1, minl)
    transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
  end

  # op1: retain, op2: delete
  defp transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position) when is_integer(op1) and is_integer(op2) and 0 <= op1 and op2 < 0 do
    [minl, op1, op2, op1_position, op2_position] = cond do
      Component.length(op1) > Component.length(op2) ->
        minl = op2
        op1  = op1 - Component.length(op2)
        op2_position = op2_position + 1
        op2 = Enum.at(op2s, op2_position)
        [minl, op1, op2, op1_position, op2_position]
      Component.length(op1) == Component.length(op2) ->
        minl = op2
        op1_position = op1_position + 1
        op2_position = op2_position + 1
        op1 = Enum.at(op1s, op1_position)
        op2 = Enum.at(op2s, op2_position)
        [minl, op1, op2, op1_position, op2_position]
      true ->
        minl = %{d: String.slice(op2.d, -Component.length(op1)..-1)}
        op2  = %{d: String.slice(op2.d, -(Component.length(op2) - Component.length(op1))..-1)}
        op1_position = op1_position + 1
        op1 = Enum.at(op1s, op1_position)
        [minl, op1, op2, op1_position, op2_position]
    end
    operation2Prime = List.insert_at(operation2Prime, -1, minl)
    transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
  end

  # Unexpected condition
  defp transform_loop(_, _, _, _, _, _, _, _) do
    raise "The two operations aren't compatible or "
  end

  @spec transform(Operation.t, Operation.t, OT.Type.side) :: Operation.t
  def transform(op1s, op2s) do
    op1 = Enum.at(op1s, 0)
    op2 = Enum.at(op2s, 0)
    transform_loop(op1s, op2s, op1, op2, [], [], 0, 0)
  end

  @spec do_transform(Scanner.output, OT.Type.side, Operation.t) :: Operation.t
  defp do_transform(next_pair, side, result \\ [])

  # Operation A is exhausted
  defp do_transform({{nil, _}, _}, _, result) do
    result
  end

  # Operation B is exhausted
  defp do_transform({{head_a, tail_a}, {nil, _}}, _, result) do
    result
    |> Operation.append(head_a)
    |> Operation.join(tail_a)
  end

  # insert / insert / left
  defp do_transform({{head_a = %{i: _}, tail_a}, {head_b = %{i: _}, tail_b}}, :left, result) do
    {tail_a, [head_b | tail_b]}
    |> next
    |> do_transform(:left, Operation.append(result, head_a))
  end

  # insert / insert / right
  defp do_transform({{head_a = %{i: _}, tail_a}, {head_b = %{i: _}, tail_b}}, :right, result) do
    {[head_a | tail_a], tail_b}
    |> next
    |> do_transform(:right, Operation.append(result, Component.length(head_b)))
  end

  # insert / retain
  defp do_transform({{head_a = %{i: _}, tail_a}, {head_b, tail_b}}, side, result) when is_integer(head_b) do
    {tail_a, [head_b | tail_b]}
    |> next
    |> do_transform(side, Operation.append(result, head_a))
  end

  # insert / delete
  defp do_transform({{head_a = %{i: _}, tail_a}, {head_b = %{d: _}, tail_b}}, side, result) do
    {tail_a, [head_b | tail_b]}
    |> next
    |> do_transform(side, Operation.append(result, head_a))
  end

  # retain / insert
  defp do_transform({{head_a, tail_a}, {head_b = %{i: _}, tail_b}}, side, result)
  when is_integer(head_a) do
    {[head_a | tail_a], tail_b}
    |> next
    |> do_transform(side, Operation.append(result, Component.length(head_b)))
  end

  # retain / retain
  defp do_transform({{head_a, tail_a}, {head_b, tail_b}}, side, result)
  when is_integer(head_a) and is_integer(head_b) do
    {tail_a, tail_b}
    |> next
    |> do_transform(side, Operation.append(result, head_a))
  end

  # retain / delete
  defp do_transform({{head_a, tail_a}, {%{d: _}, tail_b}}, side, result)
  when is_integer(head_a) do
    {tail_a, tail_b}
    |> next
    |> do_transform(side, result)
  end

  # delete / insert
  defp do_transform({{head_a = %{d: _}, tail_a}, {head_b = %{i: _}, tail_b}}, side, result) do
    {[head_a | tail_a], tail_b}
    |> next
    |> do_transform(side, Operation.append(result, Component.length(head_b)))
  end

  # delete / retain
  defp do_transform({{head_a = %{d: _}, tail_a}, {head_b, tail_b}}, side, result) when is_integer(head_b) do
    {tail_a, tail_b}
    |> next
    |> do_transform(side, Operation.append(result, head_a))
  end

  # delete / delete
  defp do_transform({{%{d: _}, tail_a}, {%{d: _}, tail_b}}, side, result) do
    {tail_a, tail_b}
    |> next
    |> do_transform(side, result)
  end

  @spec next(Scanner.input) :: Scanner.output
  defp next(scanner_input), do: Scanner.next(scanner_input, :insert)
end
