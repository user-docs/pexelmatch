defmodule Pixelmatch.Match do
  alias Pixelmatch.Matrix
  alias Pixelmatch.Compare

  defstruct img_1: %{}, img_2: %{}, deltas: %{}, diff: %{}

  # matching threshold (0 to 1); smaller is more sensitive
  @default_threshold 0.1
  # whether to skip anti-aliasing detection
  @default_include_aa false
  # opacity of original image in diff output
  @default_alpha 0.1
  # color of anti-aliased pixels in diff output
  @default_aa_color <<255, 255, 0>>
  # color of different pixels in diff output
  @default_diff_color <<255, 0, 0>>
  # whether to detect dark on light differences between img1 and img2 and set an alternative color to differentiate between the two
  @default_diff_color_alt nil
  # draw the diff over a transparent background (a mask)
  @default_diff_mask false

  def apply(pixels_1, pixels_2, output, width, height, options) do
    threshold = Map.get(options, :threshold, @default_threshold)

    opts = %{
      threshold: threshold,
      include_aa: Map.get(options, :include_aa, @default_include_aa),
      alpha: Map.get(options, :alpha, @default_alpha),
      diff_mask: Map.get(options, :diff_mask, @default_diff_mask),
      aa_color: Map.get(options, :diff_mask, @default_aa_color),
      diff_color: Map.get(options, :diff_color, @default_diff_color),
      diff_color_alt: Map.get(options, :diff_color_alt, @default_diff_color_alt),
      max_delta: 35215 * threshold * threshold
    }

    with pixels <- zip_pixels(pixels_1, pixels_2),
         state <- cast_pixels(pixels, width, height),
         {:same, false} <- {:same, identical?(state)},
         {:delta, state} <- {:delta, calculate_delta(state)},
         {:aa, state} <- {:aa, map_antialiased(state, width, height)},
         {:cmp, state} <- {:cmp, map_diff_pixel(state, opts)},
         {:write, state} <- {:write, write_diff(state, output)} do
      {:ok, state}
    else
      {:same, true} -> {:ok, :identical}
    end
  end

  def zip_pixels(pixels_1, pixels_2) do
    Enum.zip_with(pixels_1, pixels_2, fn row_1, row_2 ->
      Enum.zip(row_1, row_2)
    end)
  end

  def cast_pixels(pixels, width, height) do
    matrix = Matrix.new(width, height)

    pixels
    |> Enum.reduce({0, matrix}, fn pixel_row, {y, matrix_row} ->
      matrix_row =
        Enum.reduce(pixel_row, {0, matrix_row}, fn {pixel_1, pixel_2}, {x, matrix_val} ->
          compare = %Compare{pixel_1: pixel_1, pixel_2: pixel_2}
          {x + 1, Matrix.put(matrix_val, compare, x, y)}
        end)
        |> elem(1)

      {y + 1, matrix_row}
    end)
    |> elem(1)
  end

  def identical?(state) do
    fun = fn %{pixel_1: pixel_1, pixel_2: pixel_2}, acc, _x, _y ->
      acc && pixel_1 == pixel_2
    end

    Matrix.reduce(state, fun, true)
  end

  def calculate_delta(state) do
    fun = fn %{pixel_1: pixel_1, pixel_2: pixel_2} = value ->
      delta = color_delta(pixel_1, pixel_2, false)
      Map.put(value, :delta, delta)
    end

    Matrix.map(state, fun)
  end

  def map_antialiased(matrix, width, height) do
    fun = fn value, matrix, x, y ->
      p1_antialiased? = pixel_antialiased?(matrix, x, y, width, height, :pixel_1, :pixel_2)
      p2_antialiased? = pixel_antialiased?(matrix, x, y, width, height, :pixel_2, :pixel_1)

      value =
        value
        |> Map.put(:pixel_1_antialiased, p1_antialiased?)
        |> Map.put(:pixel_2_antialiased, p2_antialiased?)

      Matrix.put(matrix, value, x, y)
    end

    Matrix.with_index(matrix, fun)
  end

  def map_diff_pixel(matrix, opts) do
    fun = fn value, matrix, x, y ->
      %{
        pixel_1: pixel_1,
        pixel_2: pixel_2,
        pixel_1_antialiased: pixel_1_antialiased,
        pixel_2_antialiased: pixel_2_antialiased
      } = value

      delta = color_delta(pixel_1, pixel_2, false)

      value =
        {
          abs(delta) > opts.max_delta,
          not opts.include_aa && (pixel_1_antialiased || pixel_2_antialiased),
          not opts.diff_mask
        }
        |> case do
          {true, true, true} ->
            diff_pixel = draw_pixel(opts.aa_color)
            Map.put(value, :diff_pixel, diff_pixel)

          {true, _, _} ->
            color = opts.diff_color_alt || opts.diff_color
            diff_pixel = draw_pixel(color)

            value
            |> Map.put(:diff_pixel, diff_pixel)
            |> Map.put(:diff, true)

          _ ->
            diff_pixel = draw_gray_pixel(pixel_1, opts.alpha)
            Map.put(value, :diff_pixel, diff_pixel)
        end

      Matrix.put(matrix, value, x, y)
    end

    Matrix.with_index(matrix, fun)
  end

  def write_diff(matrix, out) do
    IO.inspect(out)
  end

  def pixel_antialiased?(matrix, x, y, width, height, this_key, other_key) do
    zeros = Matrix.get_zeros(x, y, width, height)

    adjacent_pixels =
      Matrix.get_adjacent_values(matrix, x, y, width, height)
      |> Enum.map(&Map.get(&1, this_key))

    pixel =
      Matrix.get(matrix, x, y)
      |> Map.get(this_key)

    init_acc = %{
      min_x: nil,
      min_y: nil,
      max_x: nil,
      max_y: nil,
      zeros: zeros,
      antialiased: nil,
      min: 0,
      max: 0
    }

    adjacent_pixels
    |> Enum.reduce(init_acc, fn adjacent_pixel, acc ->
      delta = color_delta(pixel, adjacent_pixel, true)

      case delta do
        0 ->
          Map.put(acc, :zeros, acc.zeros + 1)

        delta when delta < acc.min ->
          Map.merge(acc, %{min: delta, min_x: x, min_y: y})

        # this >= was divergent from original code
        delta when delta > acc.max ->
          Map.merge(acc, %{max: delta, max_x: x, max_y: y})

        # this was divergent from original code. handles when delta = max
        _ ->
          acc
      end
    end)
    |> case do
      %{zeros: zeros} when zeros > 2 ->
        false

      %{min: 0} ->
        false

      %{max: 0} ->
        false

      %{min_x: min_x, min_y: min_y, max_y: max_y, max_x: max_x} ->
        (has_many_siblings(matrix, this_key, min_x, min_y, width, height) &&
           has_many_siblings(matrix, other_key, min_x, min_y, width, height)) ||
          (has_many_siblings(matrix, this_key, max_x, max_y, width, height) &&
             has_many_siblings(matrix, other_key, max_x, max_y, width, height))
    end
  end

  def has_many_siblings(matrix, key, x, y, width, height) do
    zeros = Matrix.get_zeros(x, y, width, height)
    pixel = Matrix.get(matrix, x, y)

    Matrix.get_adjacent_values(matrix, x, y, width, height)
    |> Enum.map(&Map.get(&1, key))
    |> Enum.reduce(zeros, fn adjacent_pixel, acc ->
      if pixel == adjacent_pixel do
        acc + 1
      else
        acc
      end
    end)
    |> case do
      zeros when zeros > 2 -> true
      _ -> false
    end
  end

  def draw_pixel(<<r, g, b>>), do: <<r, g, b, 255>>

  def draw_gray_pixel(<<_r, _g, _b, a>> = pixel_1, alpha) do
    # dubious, this might need to get floored
    val = blend(rgb_to_y(pixel_1), alpha * a / 255)
    <<val, val, val, 255>>
  end

  def color_delta(<<r, g, b, a>>, <<r, g, b, a>>, _y_only) do
    0
  end

  def color_delta(pixel_1, pixel_2, true) do
    pixel_1 = maybe_blend_pixel(pixel_1)
    pixel_2 = maybe_blend_pixel(pixel_2)
    rgb_to_y(pixel_1) - rgb_to_y(pixel_2)
  end

  def color_delta(pixel_1, pixel_2, false) do
    pixel_1 = maybe_blend_pixel(pixel_1)
    pixel_2 = maybe_blend_pixel(pixel_2)
    y1 = rgb_to_y(pixel_1)
    y2 = rgb_to_y(pixel_2)
    y = y1 - y2

    i = rgb_to_i(pixel_1) - rgb_to_i(pixel_2)
    q = rgb_to_q(pixel_1) - rgb_to_q(pixel_2)

    delta = 0.5053 * y * y + 0.299 * i * i + 0.1957 * q * q

    case y1 > y2 do
      true -> -1 * delta
      false -> delta
    end
  end

  def maybe_blend_pixel(<<r, g, b, a>>) when a < 255,
    do: <<blend(r, a), blend(b, a), blend(g, a), div(a, 255)>>

  def maybe_blend_pixel(pixel), do: pixel

  def blend(c, a), do: 255 + (c - 255) * a

  def rgb_to_y(<<r, g, b, _>>), do: r * 0.29889531 + g * 0.58662247 + b * 0.11448223
  def rgb_to_i(<<r, g, b, _>>), do: r * 0.59597799 - g * 0.27417610 - b * 0.32180189
  def rgb_to_q(<<r, g, b, _>>), do: r * 0.21147017 - g * 0.52261711 + b * 0.31114694
end
