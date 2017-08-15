defmodule OT.Text.ComponentTest do
  use ExUnit.Case, async: true

  doctest OT.Text.Component

  alias OT.Text.Component

  describe ".invert/1" do
    test "inverts a delete" do
      assert Component.invert(-3) == 3
    end

    test "inverts an insert" do
      assert Component.invert(%{i: [98, 99, 100]}) == -3
    end

    test "inverts a retain" do
      assert Component.invert(4) == -4
    end
  end

  describe ".length/1" do
    test "determines the length of a delete" do
      assert Component.length(-3) == 3
    end

    test "determines the length of an insert" do
      assert Component.length(%{i: [98, 99, 100, 101, 102]}) == 5
    end

    test "determines the length of a retain" do
      assert Component.length(4) == 4
    end
  end

  describe ".type/1" do
    test "determines the type of a delete" do
      assert Component.type(-3) == :delete
    end

    test "determines the type of an insert" do
      assert Component.type(%{i: [98, 99, 100]}) == :insert
    end

    test "determines the type of a retain" do
      assert Component.type(4) == :retain
    end
  end

  describe ".join/2" do
    test "joins two retains" do
      assert Component.join(4, 2) == [6]
    end

    test "joins two inserts" do
      assert Component.join(%{i: [98, 99, 100]}, %{i: [198, 199, 200]}) == [%{i: [98, 99, 100, 198, 199, 200]}]
    end

    test "joins two deletes" do
      assert Component.join(-3, -3) == [-6]
    end
  end

  describe ".compare/2" do
    test "compares two components" do
      comp_a = 4
      comp_b = %{i: [100, 101, 102, 103, 104]}
      comp_c = -5

      assert Component.compare(comp_a, comp_b) == :lt
      assert Component.compare(comp_b, comp_a) == :gt
      assert Component.compare(comp_b, comp_c) == :eq
    end
  end

  describe ".split/2" do
    test "splits a delete" do
      assert Component.split(-3, 2) == {-2, -1}
    end

    test "splits an insert" do
      assert Component.split(%{i: [101, 102, 103, 104, 105]}, 3) == {%{i: [101, 102, 103]}, %{i: [104, 105]}}
    end

    test "splits a retain" do
      assert Component.split(4, 1) == {1, 3}
    end
  end
end
