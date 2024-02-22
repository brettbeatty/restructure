defmodule RestructureTest do
  use ExUnit.Case, async: true
  doctest Restructure

  describe "positional fields only" do
    defmodule Coord do
      use Restructure

      defstruct coord_2d(x, y)
      defstruct coord_3d(x, y, z)
    end

    test "returns a restructure struct" do
      import Coord
      assert %Restructure{} = coord_2d(0, 0)
    end

    test "allows matching out values" do
      import Coord

      coordinate = coord_3d(-23, 19, 42)
      assert coord_3d(x, y, z) = coordinate
      assert x == -23
      assert y == 19
      assert z == 42
    end

    test "supports values that are not their own AST" do
      import Coord

      x_before = {?a, ?b, ?c}
      y_before = %{d: ?e, f: ?g}

      coordinate = coord_2d(x_before, y_before)
      assert coord_2d(x_after, y_after) = coordinate

      assert x_after == x_before
      assert y_after == y_before
    end
  end

  describe "fetching" do
    defmodule KV do
      use Restructure

      defstruct pair(key, value)
    end

    test "supports fetching fields from struct" do
      import KV

      struct = pair(:some_key, %{some: "value"})
      assert struct[:key] == :some_key
      assert struct[:value] == %{some: "value"}
      assert struct[:fake_field] == nil
    end
  end

  describe "module-level structs" do
    defmodule OldSchool do
      use Restructure

      defstruct [:a, :b, c: "3", d: ~c"4"]
    end

    test "not interfered with" do
      struct = %OldSchool{a: 1, b: 2, c: ?c}
      assert %OldSchool{} = struct
      assert struct.a == 1
      assert struct.b == 2
      assert struct.c == ?c
      assert struct.d == ~c"4"
    end
  end

  describe "inspection" do
    defmodule Inspectable do
      use Restructure

      defstruct empty
      defstruct one_field(value)
      defstruct multi_field(a, b, c)
    end

    test "can inspect empty struct" do
      import Inspectable

      assert inspect(empty()) == "RestructureTest.Inspectable.empty()"
    end

    test "can inspect structs with one field" do
      import Inspectable
      value = %{some: [:fairly, "complex"], nested: ~c"value"}
      struct = one_field(value)

      assert inspect(struct) == "RestructureTest.Inspectable.one_field(#{inspect(value)})"
    end

    test "can inspect structs with multiple fields" do
      import Inspectable
      struct = multi_field(:some, {:arbitrary, "number", ~c"of"}, :fields)

      assert inspect(struct) ==
               ~S[RestructureTest.Inspectable.multi_field(:some, {:arbitrary, "number", ~c"of"}, :fields)]
    end
  end
end
