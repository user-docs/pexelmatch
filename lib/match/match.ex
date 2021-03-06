defmodule Pexelmatch.Match do
  @moduledoc """
  The main internal API for matching images.
  """
  alias ExPng.Image
  alias Pexelmatch.Matrix
  require Logger

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

  def apply(img_1, img_2, options) do
    threshold = Map.get(options, :threshold, @default_threshold)

    opts = %{
      width: img_1.width,
      height: img_1.height,
      threshold: threshold,
      include_aa: Map.get(options, :include_aa, @default_include_aa),
      alpha: Map.get(options, :alpha, @default_alpha),
      diff_mask: Map.get(options, :diff_mask, @default_diff_mask),
      aa_color: Map.get(options, :aa_color, @default_aa_color),
      diff_color: Map.get(options, :diff_color, @default_diff_color),
      diff_color_alt: Map.get(options, :diff_color_alt, @default_diff_color_alt),
      max_delta: 35215 * threshold * threshold
    }

    matrix_1 = Matrix.cast_image(img_1)
    matrix_2 = Matrix.cast_image(img_2)

    with {:same, false} <- {:same, matrices_identical?(matrix_1, matrix_2, opts)},
         {:cmp, %{diff_count: count, diff_img: img}} <- {:cmp, compare(matrix_1, matrix_2, opts)} do
      {:ok, count, img}
    else
      {:same, true} -> {:ok, 0, nil}
      {:cmp, _} -> {:error, "Comparison failed"}
    end
  end

  def images_identical?(%Image{} = img_1, %Image{} = img_2, opts) do
    matrix_1 = Matrix.cast_image(img_1)
    matrix_2 = Matrix.cast_image(img_2)
    matrices_identical?(matrix_1, matrix_2, opts)
  end
  def matrices_identical?(img_1, img_2, opts) do
    pixels_identical = fn(acc, x, y) ->
      if acc do
        pixel_1 = Matrix.get(img_1, {x, y})
        pixel_2 = Matrix.get(img_2, {x, y})
        # IO.inspect(pixel_1)
        # IO.inspect(pixel_2)
        # IO.puts("x: #{x}, y: #{y}, #{pixel_1 == pixel_2}")
        pixel_1 == pixel_2
      else
        acc
      end
    end

    Matrix.reduce(opts.width, opts.height, pixels_identical, true)
  end

  def compare(matrix_1, matrix_2, opts) do
    diff_img =
      Enum.map(1..opts.height, fn _ ->
        Enum.map(1..opts.width, fn _ ->
          <<0, 0, 0, 0>>
        end)
      end)
      |> ExPng.Image.new()
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

      if(abs(delta) > opts.max_delta) do
        if(not(opts.include_aa) && (p1_antialiased? || p2_antialiased?)) do
          if(not(opts.diff_mask)) do
            #IO.inspect("we will draw aa pixel #{x}, #{y}")
            pixel = draw_pixel(opts.aa_color)
            Map.put(acc, :diff_img, Image.draw(acc.diff_img, {x, y}, pixel))
          else
            acc
          end
        else
          #IO.inspect("we will draw red pixel #{x}, #{y}")
          color =
            if delta < 0 do
              opts.diff_color_alt || opts.diff_color
            else
              opts.diff_color
            end

          pixel = draw_pixel(color)
          acc
          |> Map.put(:diff_img, Image.draw(acc.diff_img, {x, y}, pixel))
          |> Map.put(:diff_count, acc.diff_count + 1)
        end
      else
        if(not(opts.diff_mask)) do
          pixel = draw_gray_pixel(pixel_1, opts.alpha)
          Map.put(acc, :diff_img, Image.draw(acc.diff_img, {x, y}, pixel))
        else
          acc
        end
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
      #IO.puts("x: #{adjacent_pixel.x}, y: #{adjacent_pixel.y}, delta: #{delta}")

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

        #IO.puts("#{x},  #{y}, #{inspect pixel}: #{min_1}, #{min_2}, #{max_1}, #{max_2}")
        (min_1 && min_2) || (max_1 && max_2)
    end
  end

  def has_many_siblings(matrix, x, y, width, height) do
    zeros = Matrix.get_zeros(x, y, width, height)
    pixel = Matrix.get(matrix, {x, y})

    Matrix.get_adjacent_values(matrix, x, y, width, height)
    |> Enum.reduce(zeros, fn adjacent_pixel, inner_zeroes ->
      if pixel == adjacent_pixel.pixel do
        inner_zeroes + 1
      else
        inner_zeroes
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
    val = blend(rgb_to_y(pixel_1), alpha * a / 255) |> floor()
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
