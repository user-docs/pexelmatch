defmodule PixelmatchTest do
	use ExUnit.Case
	doctest Pixelmatch
	alias Pixelmatch

  describe "Pixelmatch" do
    test "1a" do
      %{
        img_1_path: Path.join(".", "/test/fixtures/8a.png"),
        img_2_path: Path.join(".", "/test/fixtures/8b.png"),
        diff_path: "./test/fixtures/temp_diff.png"
      }
      |> Pixelmatch.run()


      assert %{
        img_1_path: Path.join(".", "/test/fixtures/8diff.png"),
        img_2_path: Path.join(".", "/test/fixtures/temp_diff.png"),
        diff_path: "./test/fixtures/toss.png"
      }
      |> Pixelmatch.run() == {:ok, :identical}

    end

    test "differing images return the number of different pixels" do
      opts = %{
        img_1_path: Path.join(".", "/test/4_white_pixels.png"),
        img_2_path: Path.join(".", "/test/4_black_pixels.png"),
        diff_path: "./test/diff.png"
      }
      Pixelmatch.run(opts) == {:ok, 4}
    end

    test "identical images return {:ok, :identical} tuple" do
      opts = %{
        img_1_path: Path.join(".", "/test/fixtures/4_white_pixels.png"),
        img_2_path: Path.join(".", "/test/fixtures/4_white_pixels.png"),
        diff_path: "/test/diff.png"
      }
      assert Pixelmatch.run(opts) == {:ok, :identical}
    end

    test "errors with images of different sizes" do
      opts = %{
        img_1_path: Path.join(".", "/test/fixtures/4_white_pixels.png"),
        img_2_path: Path.join(".", "/test/fixtures/white_pixel.png"),
        diff_path: "/test/diff.png"
      }
      assert Pixelmatch.run(opts) == {:error, :dimensions_different}
    end
  end

end
