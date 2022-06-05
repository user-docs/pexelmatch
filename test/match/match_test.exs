defmodule Pixelmatch.MatchTest do
  use ExUnit.Case
  alias ExPng.Image
  alias Pixelmatch.Match
  alias Pixelmatch.Matrix

  describe "has many children" do
    test "works" do
      {:ok, image} =
        Path.join(".", "/test/fixtures/8a.png")
        |> Image.from_file()

      matrix = Matrix.cast_image(image)

      Match.has_many_siblings(matrix, 3, 19, image.width, image.height)
      |> IO.inspect()
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

      # Match.antialiased?(matrix, x, y, image.width, image.height, matrix_2)
      # |> IO.inspect()

      Match.antialiased?(matrix_2, x, y, image.width, image.height, matrix)
      |> IO.inspect()
    end
  end
end
