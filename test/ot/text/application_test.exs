defmodule OT.Text.ApplicationTest do
  use ExUnit.Case, async: true

  doctest OT.Text.Application

  alias OT.Text.Application

  test "applies a simple insert component" do
    assert Application.apply([1, 2, 3], [3, %{i: [100, 101, 102, 103]}]) == {:ok, [1, 2, 3, 100, 101, 102, 103]}
  end

  test "applies a simple delete component" do
    assert Application.apply([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [7, -3]) == {:ok, [1, 2, 3, 4, 5, 6, 7]}
  end

  test "applies an implicit retain at the end of an operation" do
    assert Application.apply([1, 2, 3, 4, 5, 6, 7], [3, %{i: [100, 101, 102]}]) ==
           {:ok, [1, 2, 3, 100, 101, 102, 4, 5, 6, 7]}
  end

  test "returns an error if a retain is too long" do
    assert Application.apply([1, 2, 3], [4]) == {:error, :retain_too_long}
  end

  test "returns an error if a delete does not match" do
    assert Application.apply([1, 2, 3, 4], [3, -2]) ==
           {:error, :delete_too_long}
  end
end
