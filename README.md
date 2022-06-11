# Pexelmatch

Pexelmatch is a pure Elixir port of [Pixelmatch](https://github.com/mapbox/pixelmatch).
We used the same fixtures and tests as Pixelmatch, opting for consistency over correctness.
The library is a bit slower, and and doesn't currently offer a binary, but otherwise is feature complete.

We used the same semantics for calling the module.
We have not released a binary for it yet.
If you'd like to compare images from the command line, just use the Pixelmatch binary.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pexelmatch` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pexelmatch, "~> 0.0.1"}
  ]
end
```

## Usage

You can call the top-level API with `&Pexelmatch.run\4` or `&Pexelmatch.run\5` (with opts). 
Pass it image paths, and it will handle the file IO, and compare the images.
It will return `{:ok, number_of_pixels_changed}` and write the diff to the diff path.

```
  Pexelmatch.run("/path/image.png" "/path/image_2.png"), "./path/diff.png", opts)
  > {:ok, 1}
```

You can also call `&Pexelmatch.Match.apply\3`. 
If will not perform any file I/O, and will return `{:ok, number_of_pixels_changed, diff_data}`.
You are responsible for writing the diff data to disk.
In this example we use ExPng for file I/O.

```
  alias ExPng.Image

  {:ok, img_1} = Image.from_file("/path/img_1.png")
  {:ok, img_2} = Image.from_file("/path/img_2.png")
  {:ok, num_pixels, diff_data} = Match.apply(img_1, img_2, options)
  Image.to_file(diff_data, Path.join(".", "/test/fixtures/temp_diff.png"))
```

Options work the same way as pixelmatch, but are snake cased.