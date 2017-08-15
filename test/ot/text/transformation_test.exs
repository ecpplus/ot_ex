defmodule OT.Text.TransformationTest do
  use ExUnit.Case, async: true

  doctest OT.Text.Transformation
  alias OT.Text.Transformation

  require OT.Fuzzer
  require Logger

  test "fuzz test" do
    # OT.Fuzzer.transformation_fuzz(OT.Text, 1_000)
  end

  # @tag :slow_fuzz
  # test "slow fuzz test" do
    # OT.Fuzzer.transformation_fuzz(OT.Text, 10_000)
  # end

  test "transform both retains" do
    assert Transformation.transform([10], [10]) == [[10], [10]]
  end

  test "transform both retains->delete" do
    assert Transformation.transform([10, -1], [10, -1]) == [[10], [10]]
  end

  test "transform retain -> insert" do
    assert Transformation.transform([2, %{i: [100]}], [2, %{i: [200]}]) == [[2, %{i: [100]}, 1], [2, 1, %{i: [200]}]]
  end

  test "transform delete" do
    assert Transformation.transform([2, -2], [2, -2]) == [[2], [2]]
  end

  test "transform insert->delete" do
    assert Transformation.transform([%{i: [100, 101, 102, 103, 104]}, -2], [%{i: [200, 201, 202, 203, 204, 205]}, -2]) == [[%{i: [100, 101, 102, 103, 104]}, 6], [5, %{i: [200, 201, 202, 203, 204, 205]}]]
  end

  test "transform retain->delete->insert" do
    assert Transformation.transform([5, -2, %{i: [100, 102, 102, 103, 104, 105, 106, 107]}], [5, -2, %{i: [200, 201, 201]}]) == [[5, %{i: [100, 102, 102, 103, 104, 105, 106, 107]}, 3], [5, 8, %{i: [200, 201, 201]}]]
  end
end
