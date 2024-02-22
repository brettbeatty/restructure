defmodule RestructureTest do
  use ExUnit.Case, async: true
  doctest Restructure

  describe "ordered fields only" do
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

  describe "named fields only" do
    defmodule Bounds do
      use Restructure

      defstruct bounds(min: 0, max: 0)
    end

    test "returns a restructure struct" do
      import Bounds

      assert %Restructure{} = bounds()
    end

    test "allows matching all named" do
      import Bounds

      assert bounds(named) = bounds(min: -1, max: 1)
      assert named == %{min: -1, max: 1}
    end

    test "allows matching a subset of named" do
      import Bounds

      assert bounds(max: max) = bounds(min: 0.0, max: 8.0)
      assert max == 8.0
    end

    test "allows matching specific named" do
      import Bounds

      assert bounds(max: max, min: min) = bounds(min: -2, max: 3)
      assert min == -2
      assert max == 3
    end

    test "allows passing in named field variable" do
      import Bounds

      named = [max: 7]
      assert bounds(named) == bounds(min: 0, max: 7)
    end

    test "handles values that are not their own AST" do
      import Bounds

      assert bounds(min: %{inclusive: min}) = bounds(min: %{inclusive: 4})
      assert min == 4
    end
  end

  describe "fetching" do
    defmodule KV do
      use Restructure

      defstruct pair(key, value, meta: %{}, id: make_ref())
    end

    test "supports fetching ordered fields from struct" do
      import KV

      struct = pair(:some_key, %{some: "value"})
      assert struct[:key] == :some_key
      assert struct[:value] == %{some: "value"}
      assert struct[:fake_field] == nil
    end

    test "supports fetching named fields from struct" do
      import KV

      struct = pair(:another_key, %{another: :value}, meta: %{one: [:more, "thing"]})
      assert struct[:meta] == %{one: [:more, "thing"]}
      assert is_reference(struct[:id])
      assert struct[:one] == nil
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
      defstruct named_only(a: :b, c: %{d: "e"})
      defstruct mixed(a, b, c: "c", d: "d")
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

    test "can inspect structs with only named fields and include defaults" do
      import Inspectable

      struct = named_only()
      assert inspect(struct) == ~S[RestructureTest.Inspectable.named_only(a: :b, c: %{d: "e"})]
    end

    test "can inspect named-only structs with overrides" do
      import Inspectable

      struct = named_only(c: ?r, a: ?p)
      assert inspect(struct) == "RestructureTest.Inspectable.named_only(a: 112, c: 114)"
    end

    test "can inspect structs with a mix of ordered and named fields" do
      import Inspectable

      struct = mixed(%{letter: "a"}, B, c: "see?")

      assert inspect(struct) ==
               ~S[RestructureTest.Inspectable.mixed(%{letter: "a"}, B, c: "see?", d: "d")]
    end
  end
end
