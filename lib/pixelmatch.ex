defmodule Pexelmatch do
  alias ExPng.Image
  alias Pexelmatch.Match
  def run(img_1_path, img_2_path, diff_path, opts \\ %{}) do
    with {:img_1, {:ok, img_1 = %Image{}}} <- {:img_1, Image.from_file(img_1_path)},
         {:img_2, {:ok, img_2 = %Image{}}} <- {:img_2, Image.from_file(img_2_path)},
         {:dims, true, true} <- {:dims, img_1.height == img_2.height, img_2.width == img_2.width},
         {:match, {:ok, count, diff_data = %Image{}}} <- {:match, Match.apply(img_1, img_2, opts)},
         {:ok, _} <- Image.to_file(diff_data, diff_path) do
      {:ok, count}
    else
      {:dims, _, _} -> {:error, :dimensions_different}
      {:img_1, {:error, e, _file}} -> {:error, :"img_1_#{e}"}
      {:img_2, {:error, e, _file}} -> {:error, :"img_2_#{e}"}
      {:match, {:ok, 0, nil}} -> {:ok, 0}
    end
  end
end
