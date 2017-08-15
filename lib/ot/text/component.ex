defmodule OT.Text.Component do
  @moduledoc """
  An individual unit of work to be performed on a piece of text.

  A component represents a retain or modification of the text:

  - `5`:            Retain 5 character codes of the charcodes
  - `-5`:           Delete 5 character codes of the charcodes
  - `%{i:[98, 99, 100]}`: Insert charcodes [98, 99, 100]
  """

  alias OT.Text
  alias Text.Operation

  # for avoiding conflicting __MODULE__.length
  defp kernel_length(val) do
    k_length = &(Kernel.length/1)
    k_length.(val)
  end

  import Kernel, except: [length: 1]

  @typedoc """
  A delete component, in which a string of zero or more characters are deleted
  from the text
  """
  @type delete :: neg_integer

  @typedoc """
  An insert component, in which a string of zero or more characters are inserted
  into the text
  """
  @type insert :: %{i: Text.datum}

  @typedoc """
  A retain component, in which a number of characters in the text are skipped
  over
  """
  @type retain :: non_neg_integer

  @typedoc """
  An atom declaring the type of a component
  """
  @type type :: :delete | :insert | :retain

  @typedoc """
  The result of comparing two components
  """
  @type comparison :: :eq | :gt | :lt

  @typedoc """
  A single unit of "work" performed on a piece of text
  """
  @type t :: delete | insert | retain

  @doc """
  Invert a component.

  ## Examples

      iex> OT.Text.Component.invert(%{i: [98, 99, 100]})
      -3

      iex> OT.Text.Component.invert(-3)
      3

      iex> OT.Text.Component.invert(4)
      -4
  """
  @spec invert(t) :: t
  def invert(comp) when is_integer(comp), do: -comp
  def invert(ins=%{i: _}), do: -__MODULE__.length(ins)

  @doc """
  Determine the length of a component.

  ## Examples

      iex> OT.Text.Component.length(4)
      4

      iex> OT.Text.Component.length(%{i: [98, 99, 100]})
      3
  """

  @spec length(t) :: non_neg_integer
  def length(comp) when is_integer(comp), do: abs(comp)
  def length(%{i: ins}), do: kernel_length(ins)

  @doc """
  Determine the type of a component.

  ## Examples

      iex> OT.Text.Component.type(4)
      :retain

      iex> OT.Text.Component.type(%{i: [98, 99, 100]})
      :insert

      iex> OT.Text.Component.type(-3)
      :delete
  """
  @spec type(t) :: type
  def type(ret) when is_integer(ret) and 0 <= ret, do: :retain
  def type(del) when is_integer(del) and del < 0,  do: :delete
  def type(%{i: _}),                               do: :insert
  def type(_),                                     do: nil

  @doc """
  Compare the length of two components.

  Will return `:gt` if first is greater than second, `:lt` if first is less
  than second, or `:eq` if they span equal lengths.

  ## Example

      iex> OT.Text.Component.compare(%{i: [98, 99, 100]}, 1)
      :gt
  """
  @spec compare(t, t) :: comparison
  def compare(comp_a, comp_b) do
    length_a = __MODULE__.length(comp_a)
    length_b = __MODULE__.length(comp_b)

    cond do
      length_a > length_b -> :gt
      length_a < length_b -> :lt
      true -> :eq
    end
  end

  @doc """
  Join two components into an operation, combining them into a single component
  if they are of the same type.

  ## Example

      iex> OT.Text.Component.join(%{i: [98, 99, 100]}, %{i: [198, 199, 200]})
      [%{i: [98, 99, 100, 198, 199, 200]}]
  """
  @spec join(t, t) :: Operation.t
  def join(retain_a, retain_b)
      when is_integer(retain_a) and is_integer(retain_b) and 0 <= retain_a and 0 <= retain_b,
    do: [retain_a + retain_b]
  def join(delete_a, delete_b)
      when is_integer(delete_a) and is_integer(delete_b) and delete_a < 0 and delete_b < 0,
    do: [delete_a + delete_b]
  def join(%{i: ins_a}, %{i: ins_b}),
    do: [%{i: ins_a ++ ins_b}]
  def join(comp_a, comp_b),
    do: [comp_a, comp_b]

  @doc """
  Determine whether a comopnent is a no-op.

  ## Examples

      iex> OT.Text.Component.no_op?(0)
      true

      iex> OT.Text.Component.no_op?(%{i: []})
      true
  """
  @spec no_op?(t) :: boolean
  def no_op?(0), do: true
  def no_op?(%{i: []}), do: true
  def no_op?(_), do: false

  @doc """
  Split a component at a given index.

  Returns a tuple containing a new component before the index, and a new
  component after the index.

  ## Examples

      iex> OT.Text.Component.split(4, 3)
      {3, 1}

      iex> OT.Text.Component.split(%{i: [98,99,100]}, 2)
      {%{i: [98, 99]}, %{i: [100]}}
  """
  @spec split(t, non_neg_integer) :: {t, t}
  def split(comp, index) when is_integer(comp) and 0 <= comp do
    {index, comp - index}
  end

  def split(comp, index) when is_integer(comp) and comp < 0 do
    {-index, comp + index}
  end

  def split(%{i: ins}, index) do
    {%{i: Enum.slice(ins, 0..index-1)},
     %{i: Enum.slice(ins, index..-1)}}
  end

  @doc false
  @spec random(Text.datum) :: t
  def random(text), do: do_random(random_type(), text)

  @spec do_random(type, Text.datum) :: t
  defp do_random(:delete, text),
    do: -kernel_length(text)
  defp do_random(:insert, _text),
    do: %{i: Text.init_random(:rand.uniform(16))}
  defp do_random(:retain, text),
    do: kernel_length(text)

  @spec random_type :: type
  defp random_type, do: Enum.random([:delete, :insert, :retain])
end
