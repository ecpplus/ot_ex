defmodule OT.Text.Application do
  @moduledoc """
  The application of a text operation to a piece of text.
  """

  alias OT.Text, as: Text
  alias Text.Operation

  @typedoc """
  The result of an `apply/2` function call, representing either success or error
  in application of an operation
  """
  @type apply_result :: {:ok, OT.Text.datum}
                      | {:error, :delete_mismatch | :retain_too_long}

  @doc """
  Apply an operation to a piece of text.

  Given a piece of text and an operation, iterate over each component in the
  operation and apply it to the given text. If the operation is valid, the
  function will return `{:ok, new_state}` where `new_state` is the text with
  the operation applied to it. If the operation is invalid, an
  `{:error, atom}` tuple will be returned.

  ## Examples

      iex> OT.Text.Application.apply([1,2,3], [3, %{i: [100, 101, 102, 103]}])
      {:ok, [1, 2, 3, 100, 101, 102, 103]}

      iex> OT.Text.Application.apply([1,2,3], [-4])
      {:error, :delete_too_long}

  ## Errors

  - `:delete_mismatch` A delete component did not match the text it would have
    deleted in the text
  - `:retain_too_long` A retain component skipped past the end of the text
  """
  @spec apply(Text.datum, Operation.t) :: apply_result
  def apply(text, op), do: do_apply(text, op)

  @doc """
  Same as `apply/2`, but raises if the application fails.
  """
  @spec apply!(Text.datum, Operation.t) :: Text.datum | no_return
  def apply!(text, op) do
    with {:ok, result} <- __MODULE__.apply(text, op) do
      result
    else
      {:error, error} -> raise to_string(error)
    end
  end

  @spec do_apply(Text.datum, Operation.t, Text.datum) :: apply_result
  defp do_apply(text, op, result \\ [])

  defp do_apply(text, [], result) do
    {:ok, result ++ text}
  end

  defp do_apply(text, [%{i: ins} | op], result) do
    text
    |> do_apply(op, result ++ ins)
  end

  defp do_apply(text, [ret | op], result) when is_integer(ret) and 0 <= ret do
    if ret <= length(text) do
      retained = Enum.slice(text, 0..ret-1)
      text     = Enum.slice(text, ret..-1)

      text
      |> do_apply(op, result ++ retained)
    else
      {:error, :retain_too_long}
    end
  end

  defp do_apply(text, [del | op], result) when is_integer(del) and del < 0 do
    if abs(del) <= length(text) do
      text = Enum.slice(text, -del..-1)

      text
      |> do_apply(op, result)
    else
      {:error, :delete_too_long}
    end
  end
end
