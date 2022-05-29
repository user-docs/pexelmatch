defmodule Pixelmatch.MatrixTest do
	use ExUnit.Case
	alias Pixelmatch.Matrix

  describe "Mappers" do
    test "with_index modifies array" do
      fun = fn(val, matrix, x, y) ->
        Matrix.put(matrix, val * 2, x, y)
      end
      array = Arrays.new([
        Arrays.new([1, 2]),
        Arrays.new([1, 2]),
      ])
      result = Matrix.with_index(array, fun)
      assert result == Arrays.new([
        Arrays.new([2, 4]),
        Arrays.new([2, 4]),
      ])
    end
  end

  describe "Get Adjacent Ranges" do
    test "fetches all ranges adjacent to 0, 0 in a 2 X 2 array" do
      assert Matrix.get_adjacent_ranges(0, 0, 2, 2)  == {0..1, 0..1}
    end
  end

  describe "Get Adjacent Coordinates" do
    test "fetches adjacent coordinates" do
      assert Matrix.get_adjacent_coordinates(0, 0, 2, 2) == [{1, 0}, {0, 1}, {1, 1}]
    end
  end
end
