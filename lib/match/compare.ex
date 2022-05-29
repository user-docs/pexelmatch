defmodule Pixelmatch.Compare do
  defstruct [
    pixel_1: nil,
    pixel_2: nil,
    delta: nil,
    diff_pixel: nil,
    pixel_1_antialiased: nil,
    pixel_2_antialiased: nil,
    diff: false
  ]
end
