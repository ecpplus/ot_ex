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

  def transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position) do
    # At every iteration of the loop, the imaginary cursor that both
    # operation1 and operation2 have that operates on the input string must
    # have the same position in the input string.


    # minl = nil

    # next two cases: one or both ops are insert ops
    # => insert the string in the corresponding prime operation, skip it in
    # the other one. If both op1 and op2 are insert ops, prefer op1.
    Logger.debug("[loop] op1: #{inspect op1}, op2: #{inspect op2}")
    Logger.debug("#{inspect operation1Prime}, #{inspect operation2Prime}")

    cond do
      op1 == nil && op2 == nil ->
        # end condition: both ops1 and ops2 have been processed
        # Somehow return
        [operation1Prime, operation2Prime]
      Component.type(op1) == :insert ->
        operation1Prime = List.insert_at(operation1Prime, -1, op1)
        operation2Prime = List.insert_at(operation2Prime, -1, Component.length(op1))
        op1_position = op1_position + 1
        op1 = Enum.at(op1s, op1_position)
        transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
      Component.type(op2) == :insert ->
        operation1Prime = List.insert_at(operation1Prime, -1, Component.length(op2))
        operation2Prime = List.insert_at(operation2Prime, -1, op2)
        op2_position = op2_position + 1
        op2 = Enum.at(op2s, op2_position)
        transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
      op1 == nil || op2 == nil ->
        Logger.error("Cannot transform operations: first operation is too short. op1: #{inspect op1}, op2: #{inspect op2}")
        raise 'Cannot transform operations: first operation is too short.'
      Component.type(op1) == :retain && Component.type(op2) == :retain ->
        # Simple case: retain/retain
        cond do
          Component.length(op1) > Component.length(op2) ->
            minl = op2
            op1  = op1 - op2
            # ^op2 = ops2[i2 += 1]
            op2_position = op2_position + 1
            op2 = Enum.at(op2s, op2_position)
            operation1Prime = List.insert_at(operation1Prime, -1, minl)
            operation2Prime = List.insert_at(operation2Prime, -1, minl)
            transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
          Component.length(op1) == Component.length(op2) ->
            minl = op2
            # ^op1 = ops1[i1 += 1]
            # ^op2 = ops2[i2 += 1]
            op1_position = op1_position + 1
            op2_position = op2_position + 1
            op1 = Enum.at(op1s, op1_position)
            op2 = Enum.at(op2s, op2_position)
            operation1Prime = List.insert_at(operation1Prime, -1, minl)
            operation2Prime = List.insert_at(operation2Prime, -1, minl)
            transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
          true ->
            minl = op1
            op2  = op2 - op1
            # ^op1 = ops1[i1 += 1]
            op1_position = op1_position + 1
            op1 = Enum.at(op1s, op1_position)
            operation1Prime = List.insert_at(operation1Prime, -1, minl)
            operation2Prime = List.insert_at(operation2Prime, -1, minl)
            transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
        end

        # List.insert_at(operation1Prime, -1, minl)
        # List.insert_at(operation2Prime, -1, minl)
        # transform_loop(op1s, op2s, operation1Prime, operation2Prime, op1_position, op2_position + 1)
      Component.type(op1) == :delete && Component.type(op2) == :delete ->
        Logger.debug("both are delete")
        # Both operations delete the same string at the same position. We don't
        # need to produce any operations, we just skip over the delete ops and
        # handle the case that one operation deletes more than the other.
        cond do
          Component.length(op1) > Component.length(op2) ->
            # new_length = Component.length(op1) - Component.length(op2)
            op1 = %{d: String.slice(op1.d, Component.length(op2)..-1)}
            # ^op2 = ops2[i2 += 1]
            op2_position = op2_position + 1
            op2 = Enum.at(op2s, op2_position)
            transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
          Component.length(op1) == Component.length(op2) ->
            # op1 = ops1[i1 += 1]
            # op2 = ops2[i2 += 1]
            op1_position = op1_position + 1
            op2_position = op2_position + 1
            op1 = Enum.at(op1s, op1_position)
            op2 = Enum.at(op2s, op2_position)
            transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
          true ->
            # op2 = op2 - op1
            op2 = %{d: String.slice(op2.d, Component.length(op1)..-1)}
            # op1 = ops1[i1 += 1]
            op1_position = op1_position + 1
            op1 = Enum.at(op1s, op1_position)
            transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
        end
        # next two cases: delete/retain and retain/delete
      Component.type(op1) == :delete && Component.type(op2) == :retain ->
        cond do
          Component.length(op1) > Component.length(op2) ->
            # minl = op2
            minl = %{d: String.slice(op1.d, -Component.length(op2)..-1)}
            # op1  = op1 + op2
            # 元の文字を記憶していないといけないため、ダミーで入れる
            # op1 = %{d: String.duplicate("a", Component.length(op2)) <> op1.d}
            op1 = minl
            # op2 = ops2[i2 += 1]
            op2_position = op2_position + 1
            op2 = Enum.at(op2s, op2_position)
            operation1Prime = List.insert_at(operation1Prime, -1, minl)
            transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
          Component.length(op1) == Component.length(op2) ->
            minl = op2
            op1_position = op1_position + 1
            op2_position = op2_position + 1
            # op1 = ops1[i1 += 1]
            # op2 = ops2[i2 += 1]
            op1 = Enum.at(op1s, op1_position)
            op2 = Enum.at(op2s, op2_position)
            operation1Prime = List.insert_at(operation1Prime, -1, -minl)
            transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
          true ->
            Logger.debug("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
            # minl = -op1
            minl = op1
            op2  = op2 - Comopnent.length(op1)
            op1_position = op1_position + 1
            op1 = Enum.at(op1s, op1_position)
            # operation1Prime = List.insert_at(operation1Prime, -1, -minl)
            operation1Prime = List.insert_at(operation1Prime, -1, minl)
            # op1 = ops1[i1 += 1]
            transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
        end

        # operation1Prime.delete(minl)

      Component.type(op1) == :retain && Component.type(op2) == :delete ->
        cond do
          Component.length(op1) > Component.length(op2) ->
            minl = -op2
            op1  = op1 + op2
            # op2 = ops2[i2 += 1]
            op2_position = op2_position + 1
            op2 = Enum.at(op2s, op2_position)
            operation2Prime = List.insert_at(operation2Prime, -1, -minl)
            transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
          Component.length(op1) == Component.length(op2) ->
            minl = op1
            op1_position = op1_position + 1
            op2_position = op2_position + 1
            op1 = Enum.at(op1s, op1_position)
            op2 = Enum.at(op2s, op2_position)
            # op1 = ops1[i1 += 1]
            # op2 = ops2[i2 += 1]
            operation2Prime = List.insert_at(operation2Prime, -1, -minl)
            transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
          true ->
            minl = op1
            # op2  = op2 + op1
            # 元の文字を記憶していないといけないため、ダミーで入れる
            op2 = %{d: String.duplicate("a", Component.length(op1)) <> op2.d}
            # op1 = ops1[i1 += 1]
            op1_position = op1_position + 1
            op1 = Enum.at(op1s, op1_position)
            operation2Prime = List.insert_at(operation2Prime, -1, -minl)
            transform_loop(op1s, op2s, op1, op2, operation1Prime, operation2Prime, op1_position, op2_position)
        end
      true ->
        raise "The two operations aren't compatible"
    end
    # transform_loop(op1s, op2s, operation1Prime, operation2Prime, op1_position, op2_position)
  end

  @spec transform(Operation.t, Operation.t, OT.Type.side) :: Operation.t
  def transform(op1s, op2s) do
    # {op1s, op2s}
    # |> next
    # |> do_transform(side)



    # if (op1s.base_length != op2s.base_length)
    # fail 'Both operations have to have the same base length'
    # end

    # operation1Prime = []
    # operation2Prime = []

    # ^ops1 = op1s
    # ^ops2 = op2s

    # i1 = 0
    # i2 = 0

    # op1 = Enum.at(ops1, i1)
    # op2 = Enum.at(ops2, i2)

    # TODO: loop を実装すること
    op1_position = 0
    op2_position = 0
    op1 = Enum.at(op1s, op1_position)
    op2 = Enum.at(op2s, op2_position)

    Logger.debug("[loop start] op1s: #{inspect op1s}, op2s: #{inspect op2s}")
    operation_primes = transform_loop(op1s, op2s, op1, op2, [], [], op1_position, op2_position)
    Logger.debug("[loop finish] #{inspect operation_primes}")
    operation_primes
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
