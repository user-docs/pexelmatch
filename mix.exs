defmodule Pexelmatch.MixProject do
  use Mix.Project

  def project do
    [
      app: :pexelmatch,
      version: "0.0.1",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
end
