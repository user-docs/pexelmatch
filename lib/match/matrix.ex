defmodule Pixelmatch.Matrix do
  alias ExPng.Image

  def cast_image(%Image{} = image) do
    Enum.map(image.pixels, &Arrays.new/1)
    |> Arrays.new()
  end

  def get(matrix, {x, y}) do
    row = Arrays.get(matrix, y)
    Arrays.get(row, x)
  end

  def reduce(width, height, fun, acc) do
    Enum.reduce(0..height - 1, acc, fn y, y_acc ->
      Enum.reduce(0..width - 1, y_acc, fn x, x_acc ->
        fun.(x_acc, x, y)
      end)
    end)
  end

  def get_adjacent_values(matrix, x, y, width, height) do
    get_adjacent_coordinates(x, y, width, height)
    |> Enum.map(fn {x, y} ->
      %{x: x, y: y, pixel: get(matrix, {x, y})}
    end)
  end

  def get_adjacent_coordinates(x, y, width, height) do
    {x_range, y_range} = get_adjacent_ranges(x, y, width, height)

    Enum.map(y_range, fn inner_y ->
      Enum.map(x_range, fn inner_x ->
        {inner_x, inner_y}
      end)
    end)
    |> List.flatten()
    |> Enum.filter(& &1 != {x, y})
  end

  def get_adjacent_ranges(x, y, width, height) do
    {{x_min, x_max}, {y_min, y_max}} = get_adjacent_bounds(x, y, width, height)

    x_range = x_min..x_max
    y_range = y_min..y_max

    {x_range, y_range}
  end

  def get_zeros(x, y, width, height) do
    {{x_min, x_max}, {y_min, y_max}} = get_adjacent_bounds(x, y, width, height)
    if x_min == x || x_min == x_max || y_min == y || y_min == y_max, do: 0, else: 1
  end

  def get_adjacent_bounds(x, y, width, height) do
    x_min = max(x - 1, 0)
    y_min = max(y - 1, 0)
    x_max = min(x + 1, width - 1)
    y_max = min(y + 1, height - 1)
    {{x_min, x_max}, {y_min, y_max}}
  end
end
