defmodule OT.Text.OperationTest do
  use ExUnit.Case, async: true

  doctest OT.Text.Operation

  alias OT.Text.Operation

  require OT.Fuzzer

  describe ".append/2" do
    test "ignores a no-op component" do
      assert Operation.append([4], 0) == [4]
    end

    test "appends a component of the same type as the last in the op" do
      assert Operation.append([4], 2) == [6]
    end

    test "appends a component of a different type as the last in the op" do
      assert Operation.append([4], %{i: [98, 99, 100]}) == [4, %{i: [98, 99, 100]}]
    end
  end

  describe ".invert/1" do
    test "inverts an operation" do
      assert Operation.invert([4, %{i: [98, 99, 100]}, -3, 3]) ==
        [-4, -3, 3, -3]
    end
  end

  describe ".join/2" do
    test "joins two operations with a common terminus type" do
      assert Operation.join([%{i: [98, 99, 100]}], [%{i: [198, 199, 200]}]) ==
             [%{i: [98, 99, 100, 198, 199, 200]}]
    end

    test "joins two operations with different terminus types" do
      assert Operation.join([%{i: [98, 99, 100]}], [-3]) ==
             [%{i: [98, 99, 100]}, -3]
    end
  end

  # test "invert fuzz test" do
    # OT.Fuzzer.invert_fuzz(OT.Text, 1_000)
  # end

  # @tag :slow_fuzz
  # test "slow invert fuzz test" do
    # OT.Fuzzer.invert_fuzz(OT.Text, 10_000)
  # end
end
