defmodule Pixelmatch.MatchTest do
  use ExUnit.Case
  alias ExPng.Image
  alias Pixelmatch.Match
  alias Pixelmatch.Matrix

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

      x = 9
      y = 21

      Match.antialiased?(matrix, x, y, image.width, image.height, matrix_2)
    end
  end
end
