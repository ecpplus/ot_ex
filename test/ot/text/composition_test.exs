defmodule OT.Text.CompositionTest do
  use ExUnit.Case, async: true

  doctest OT.Text.Composition

  alias OT.Text.Composition

  require OT.Fuzzer

  test "composes an insert over an insert" do
    assert Composition.compose([%{i: [98, 99]}], [%{i: [198, 199]}]) ==
           [%{i: [198, 199, 98, 99]}]
  end

  test "composes a retain over an insert" do
    assert Composition.compose([3], [%{i: [98, 99, 100]}]) ==
           [%{i: [98, 99, 100]}, 3]
  end

  test "composes a delete over an insert" do
    assert Composition.compose([-3], [%{i: [98, 99, 100]}]) ==
           [%{i: [98, 99, 100]}, -3]
  end

  test "composes an insert over a retain" do
    assert Composition.compose([%{i: [98, 99, 100]}], [2, %{i: [198, 199, 200]}]) ==
           [%{i: [98, 99, 198, 199, 200, 100]}]
  end

  test "composes an insert over a delete" do
    assert Composition.compose([%{i: [98, 99, 100]}], [-3]) ==
           []
  end

  test "composes a retain over a retain" do
    assert Composition.compose([3, %{i: [98, 99, 100]}], [3, %{i: [198, 199, 200]}]) ==
           [3, %{i: [198, 199, 200, 98, 99, 100]}]
  end

  test "composes a retain over a delete" do
    assert Composition.compose([3, %{i: [98, 99, 100]}], [-3, %{i: [198, 199, 200]}]) ==
           [-3, %{i: [198, 199, 200, 98, 99, 100]}]
  end

  test "composes a delete over a retain" do
    assert Composition.compose([-4], [4]) ==
           [-4, 4]
  end

  test "composes a delete over a delete" do
    assert Composition.compose([-3], [-3]) ==
           [-6]
  end

  test "fuzz test" do
    # OT.Fuzzer.composition_fuzz(OT.Text, 1_000)
  end

  # @tag :slow_fuzz
  # test "slow fuzz test" do
    # OT.Fuzzer.composition_fuzz(OT.Text, 10_000)
  # end
end
