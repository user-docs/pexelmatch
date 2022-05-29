defmodule Pixelmatch.Matrix do
  defstruct rows: %{}

  def new(width, height) do
    Enum.map(1..height, fn _ -> Arrays.new(1..width) end)
    |> Arrays.new()
  end

  def with_index(matrix, fun) do
    {_, matrix} =
      Enum.reduce(matrix, {0, matrix}, fn row, {row_index, row_matrix} ->
        {_, row_matrix} =
          Enum.reduce(row, {0, row_matrix}, fn val, {val_index, val_matrix} ->
            val_matrix = fun.(val, val_matrix, val_index, row_index)
            {val_index + 1, val_matrix}
          end)

        {row_index + 1, row_matrix}
      end)

    matrix
  end

  def map(matrix, fun) do
    Arrays.map(matrix, fn row ->
      Arrays.map(row, fn value ->
        fun.(value)
      end)
    end)
  end

  def reduce(rows, fun, acc) do
    {_x, acc} =
      Enum.reduce(rows, {0, acc}, fn row, {y, row_acc} ->
        {y, row_acc} =
          Enum.reduce(row, {0, row_acc}, fn value, {x, val_acc} ->
            val_acc = fun.(value, val_acc, x, y)
            {x + 1, val_acc}
          end)

        {y + 1, row_acc}
      end)

    acc
  end

  def get(matrix, x, y) do
    row = Arrays.get(matrix, y)
    Arrays.get(row, x)
  end

  def get_row(matrix, y) do
    Arrays.get(matrix, y)
  end

  def get_adjacent_values(matrix, x, y, width, height) do
    get_adjacent_coordinates(x, y, width, height)
    |> Enum.map(fn {x, y} ->
      get(matrix, x, y)
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

  def put(matrix, value, x, y) do
    row = matrix[y]
    row = put_in(row[x], value)
    put_in(matrix[y], row)
  end
end
