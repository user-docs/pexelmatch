defmodule Pexelmatch.MatchTest do
  use ExUnit.Case
  alias ExPng.Image
  alias Pexelmatch.Match
  alias Pexelmatch.Matrix

  @default_options %{threshold: 0.05}

  describe "Integration Tests" do
    test "1-1" do
      diff_test("1a", "1b", "1diff", @default_options, 143)
    end

    test "1-2" do
      options = %{threshold: 0.05, include_aa: false, diff_mask: true}
      diff_test("1a", "1b", "1diffmask", options, 143)
    end

    test "1-3" do
      options = %{threshold: 0, diff_mask: true}
      diff_test("1a", "1a", "1emptydiffmask", options, 0)
    end

    test "2" do
      options = %{
        threshold: 0.05,
        alpha: 0.5,
        aa_color: <<0, 192, 0>>,
        diff_color: <<255, 0, 255>>
      }
      diff_test("2a", "2b", "2diff", options, 12437);
    end
    test "3" do
      diff_test("3a", "3b", "3diff", @default_options, 212);
    end
    test "4" do
      diff_test("4a", "4b", "4diff", @default_options, 36049);
    end
    test "5" do
      diff_test("5a", "5b", "5diff", @default_options, 0);
    end
    test "6-1" do
      diff_test("6a", "6b", "6diff", @default_options, 51);
    end
    test "6-2" do
      diff_test("6a", "6a", "6empty", %{threshold: 0}, 0);
    end
    test "7" do
      diff_test("7a", "7b", "7diff", %{diff_color_alt: <<0, 255, 0>>}, 2448);
    end
    test "8" do
      diff_test("8a", "8b", "8diff", @default_options, 24);
    end
  end

  describe "has many children" do
    test "works" do
      {:ok, image} =
        Path.join(".", "/test/fixtures/8a.png")
        |> Image.from_file()

      matrix = Matrix.cast_image(image)

      Match.has_many_siblings(matrix, 3, 19, image.width, image.height)
    end
  end

  describe "Antialiasing" do
    test "works" do
      {:ok, image} =
        Path.join(".", "/test/fixtures/8a.png")
        |> Image.from_file()

      {:ok, image_2} =
        Path.join(".", "/test/fixtures/8b.png")
        |> Image.from_file()

      matrix = Matrix.cast_image(image)
      matrix_2 = Matrix.cast_image(image_2)

      x = 3
      y = 20

      Match.antialiased?(matrix_2, x, y, image.width, image.height, matrix)
    end
  end

  def diff_test(img_1_path, img_2_path, diff_path, options, expected_num_pixels) do
    {:ok, img_1} = Image.from_file(Path.join(".", "/test/fixtures/#{img_1_path}.png"))
    {:ok, img_2} = Image.from_file(Path.join(".", "/test/fixtures/#{img_2_path}.png"))
    {:ok, num_pixels, diff_data} = Match.apply(img_1, img_2, options)
    assert expected_num_pixels == num_pixels
    if (diff_data) do
      {:ok, expected_diff} = Image.from_file(Path.join(".", "/test/fixtures/#{diff_path}.png"))
      Match.images_identical?(expected_diff, diff_data, %{width: diff_data.width, height: diff_data.height})
    end
  end
end
