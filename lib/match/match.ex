defmodule Pixelmatch.Match do
  alias ExPng.Image
  alias Pixelmatch.Matrix

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

  @spec apply(any, any, binary, pos_integer, pos_integer, map) :: {:ok, any}
  def apply(img_1, img_2, output, width, height, options) do
    threshold = Map.get(options, :threshold, @default_threshold)

    opts = %{
      width: width,
      height: height,
      threshold: threshold,
      include_aa: Map.get(options, :include_aa, @default_include_aa),
      alpha: Map.get(options, :alpha, @default_alpha),
      diff_mask: Map.get(options, :diff_mask, @default_diff_mask),
      aa_color: Map.get(options, :diff_mask, @default_aa_color),
      diff_color: Map.get(options, :diff_color, @default_diff_color),
      diff_color_alt: Map.get(options, :diff_color_alt, @default_diff_color_alt),
      max_delta: 35215 * threshold * threshold
    }
    #{:same, false} <- {:same, images_identical?(img_1, img_2, opts)},

    matrix_1 = Matrix.cast_image(img_1)
    matrix_2 = Matrix.cast_image(img_2)

    with {:cmp, %{diff_count: count, diff_img: img}} <- {:cmp, compare(matrix_1, matrix_2, opts)},
         {:write, {:ok, _}} <- {:write, Image.to_file(img, output)} do
      {:ok, count}
    else
      {:same, true} -> {:ok, :identical}
    end
  end

  def images_identical?(img_1, img_2, opts) do
    pixels_identical = fn(acc, x, y) ->
      if acc do
        Image.at(img_1, {x, y}) == Image.at(img_2, {x, y})
      else
        acc
      end
    end

    Matrix.reduce(opts.width, opts.height, pixels_identical, true)
  end

  def compare(matrix_1, matrix_2, opts) do
    diff_img = ExPng.Image.new(opts.width, opts.height)
    init_acc = %{
      diff_count: 0,
      diff_img: diff_img
    }
    compare = fn(acc, x, y) ->
      pixel_1 = Matrix.get(matrix_1, {x, y})
      pixel_2 = Matrix.get(matrix_2, {x, y})
      delta = color_delta(pixel_1, pixel_2, false)

      p1_antialiased? = antialiased?(matrix_1, x, y, opts.width, opts.height, matrix_2)
      p2_antialiased? = antialiased?(matrix_2, x, y, opts.width, opts.height, matrix_1)

      #IO.puts("p1: #{p1_antialiased?} p2: #{p2_antialiased?}")

      {
        abs(delta) > opts.max_delta,
        not(opts.include_aa) && (p1_antialiased? || p2_antialiased?),
        not(opts.diff_mask)
      }
      |> case do
        {true, true, true} ->
          IO.puts("x: #{x}, y: #{y} is antialiased")
          pixel = draw_pixel(opts.aa_color)
          Map.put(acc, :diff_img, Image.draw(acc.diff_img, {x, y}, pixel))

        {true, _, _} ->
          color = opts.diff_color_alt || opts.diff_color
          pixel = draw_pixel(color)
          acc
          |> Map.put(:diff_img, Image.draw(acc.diff_img, {x, y}, pixel))
          |> Map.put(:diff_count, acc.diff_count + 1)

        _ ->
          pixel = draw_gray_pixel(pixel_1, opts.alpha)
          Map.put(acc, :diff_img, Image.draw(acc.diff_img, {x, y}, pixel))
      end
    end

    Matrix.reduce(opts.width, opts.height, compare, init_acc)
  end

  def antialiased?(matrix, x, y, width, height, other_matrix) do
    zeros = Matrix.get_zeros(x, y, width, height)
    adjacent_pixels = Matrix.get_adjacent_values(matrix, x, y, width, height)
    pixel = Matrix.get(matrix, {x, y})
    #|> IO.inspect(label: :current_pixel)

    init_acc = %{
      min_x: nil,
      min_y: nil,
      max_x: nil,
      max_y: nil,
      zeros: zeros,
      min: 0,
      max: 0
    }

    adjacent_pixels
    |> Enum.reduce(init_acc, fn adjacent_pixel, acc ->
      delta = color_delta(pixel, adjacent_pixel.pixel, true)

      # IO.inspect(adjacent_pixel, label: :adjacent_pixel)

      case delta do
        0 ->
          Map.put(acc, :zeros, acc.zeros + 1)

        delta when delta < acc.min ->
          acc
          |> Map.put(:min, delta)
          |> Map.put(:min_x, adjacent_pixel.x)
          |> Map.put(:min_y, adjacent_pixel.y)

        delta when delta > acc.max ->
          acc
          |> Map.put(:max, delta)
          |> Map.put(:max_x, adjacent_pixel.x)
          |> Map.put(:max_y, adjacent_pixel.y)

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
        min_1 = has_many_siblings(matrix,        min_x, min_y, width, height)
        min_2 = has_many_siblings(other_matrix,  min_x, min_y, width, height)

        max_1 = has_many_siblings(matrix,        max_x, max_y, width, height)
        max_2 = has_many_siblings(other_matrix,  max_x, max_y, width, height)

        #IO.puts("#{x},  #{y}, #{inspect pixel}: #{min_1}, #{min_2}, #{max_1}. #{max_2}")
        (min_1 && min_2) || (max_1 && max_2)
    end
  end

  def has_many_siblings(matrix, x, y, width, height) do
    zeros = Matrix.get_zeros(x, y, width, height)
    pixel = Matrix.get(matrix, {x, y})

    Matrix.get_adjacent_values(matrix, x, y, width, height)
    |> Enum.reduce(zeros, fn adjacent_pixel, acc ->
      if pixel == adjacent_pixel.pixel do
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
    val = blend(rgb_to_y(pixel_1), alpha * a / 255) |> round()
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
