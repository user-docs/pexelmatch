defmodule PexelmatchTest do
	use ExUnit.Case
	doctest Pexelmatch
	alias Pexelmatch

  describe "2" do
    test "differing images return the number of different pixels" do
      assert Pexelmatch.run(
        Path.join(".", "/test/fixtures/4_white_pixels.png"),
        Path.join(".", "/test/fixtures/4_black_pixels.png"),
        "./test/diff.png"
       ) == {:ok, 4}
    end

    test "identical images return {:ok, :identical} tuple" do
      assert Pexelmatch.run(
        Path.join(".", "/test/fixtures/4_white_pixels.png"),
        Path.join(".", "/test/fixtures/4_white_pixels.png"),
        "/test/diff.png"
      ) == {:ok, 0}
    end

    test "errors with images of different sizes" do
      assert Pexelmatch.run(
        Path.join(".", "/test/fixtures/4_white_pixels.png"),
        Path.join(".", "/test/fixtures/white_pixel.png"),
        "/test/diff.png"
      ) == {:error, :dimensions_different}
    end
  end
end
