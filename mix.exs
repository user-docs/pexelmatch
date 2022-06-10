defmodule Pexelmatch.MixProject do
  use Mix.Project

  @version "0.0.1"
  @url "https://github.com/user-docs/pexelmatch"
  @description """
  Pure Elixir pixel-level image comparison library. A rewrite of the excellent pixelmatch library.
  """

  def project do
    [
      app: :pexelmatch,
      description: @description,
      version: @version,
      url: @url,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:arrays, "~> 2.0"},
      {:ex_png, "~> 1.0.0"}
    ]
  end


  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @url}
    ]
  end
end
