defmodule Pexelmatch.MatrixTest do
  use ExUnit.Case
  alias Pexelmatch.Matrix
  alias ExPng.Image

  describe "cast" do
    test "cast image" do
      assert %Arrays.Implementations.MapArray{} =
               Image.from_file("./test/fixtures/8a.png")
               |> elem(1)
               |> Matrix.cast_image()
    end
  end

  describe "Get Adjacent Ranges" do
    test "fetches all ranges adjacent to 0, 0 in a 2 X 2 array" do
      assert Matrix.get_adjacent_ranges(0, 0, 2, 2) == {0..1, 0..1}
    end
  end

  describe "Get Adjacent Coordinates" do
    test "fetches adjacent coordinates" do
      assert Matrix.get_adjacent_coordinates(0, 0, 2, 2) == [{0, 1}, {1, 0}, {1, 1}]
    end
  end
end
