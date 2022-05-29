defmodule Pixelmatch do
  alias ExPng.Image
  alias Pixelmatch.Match
  def run(opts) do
    img_1_path = Map.get(opts, :img_1_path, nil)
    img_2_path = Map.get(opts, :img_2_path, nil)
    diff_path = Map.get(opts, :diff_path, nil)

    if img_1_path == nil, do: raise("Image 1 path required")
    if img_2_path == nil, do: raise("Image 2 path required")
    if diff_path == nil, do: raise("diff path required")

    with {:img_1, {:ok, img_1 = %Image{}}} <- {:img_1, Image.from_file(img_1_path)},
         {:img_2, {:ok, img_2 = %Image{}}} <- {:img_2, Image.from_file(img_2_path)},
         {:dims, true, true} <- {:dims, img_1.height == img_2.height, img_2.width == img_2.width} do
      Match.apply(img_1.pixels, img_2.pixels, diff_path, img_1.width, img_1.height, %{})
    else
      {:dims, _, _} -> {:error, :dimensions_different}
      {:img_1, {:error, e, _file}} -> {:error, :"img_1_#{e}"}
      {:img_2, {:error, e, _file}} -> {:error, :"img_2_#{e}"}
    end
  end
end
