defmodule PixelmatchTest do
	use ExUnit.Case
	doctest Pixelmatch
	alias Pixelmatch

  describe "Pixelmatch" do
    test "differing images return {:ok, :different} tuple" do
      opts = %{
        img_1_path: Path.join(".", "/test/4_white_pixels.png"),
        img_2_path: Path.join(".", "/test/4_black_pixels.png"),
        diff_path: "/test/diff.png"
      }
      Pixelmatch.run(opts) == {:ok, :different}
    end

    test "identical images return {:ok, :identical} tuple" do
      opts = %{
        img_1_path: Path.join(".", "/test/4_white_pixels.png"),
        img_2_path: Path.join(".", "/test/4_white_pixels.png"),
        diff_path: "/test/diff.png"
      }
      assert Pixelmatch.run(opts) == {:ok, :identical}
    end

    test "errors with images of different sizes" do
      opts = %{
        img_1_path: Path.join(".", "/test/4_white_pixels.png"),
        img_2_path: Path.join(".", "/test/white_pixel.png"),
        diff_path: "/test/diff.png"
      }
      assert Pixelmatch.run(opts) == {:error, :dimensions_different}
    end
  end

end
