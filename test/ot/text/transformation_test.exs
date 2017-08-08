defmodule OT.Text.TransformationTest do
  use ExUnit.Case, async: true

  doctest OT.Text.Transformation
  alias OT.Text.Transformation

  require OT.Fuzzer
  require Logger

  test "fuzz test" do
    OT.Fuzzer.transformation_fuzz(OT.Text, 1_000)
  end

  @tag :slow_fuzz
  test "slow fuzz test" do
    OT.Fuzzer.transformation_fuzz(OT.Text, 10_000)
  end

  test "transform retain -> insert" do
    assert Transformation.transform([2, %{i: "p"}], [2, %{i: "q"}]) == [[2, %{i: "p"}, 1], [2, 1, %{i: "q"}]]
  end

  test "transform delete" do
    assert Transformation.transform([2, %{d: "p"}], [2, %{d: "q"}]) == [[2], [2]]
  end

  test "transform insert->delete" do
    assert Transformation.transform([%{i: "apple"}, %{d: "le"}], [%{i: "orange"}, %{d: "ge"}]) == [[%{i: "apple"}, 6], [5, %{i: "orange"}]]
  end

  test "transform retain->delete->insert" do
    assert Transformation.transform([5, %{d: "le"}, %{i: "LE JUICE"}], [5, %{d: "le"}, %{i: "GES"}]) == [[5, %{i: "LE JUICE"}, 3], [5, 8, %{i: "GES"}]]
  end
end
