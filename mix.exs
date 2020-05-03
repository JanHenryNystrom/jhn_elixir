defmodule JhnElixir.MixProject do
  use Mix.Project

  def project do
    [app: :jhn_elixir,
     version: "0.1.0",
     elixir: "~> 1.9",
     start_permanent: Mix.env() == :prod,
     description: description(),
     package: package(),
     deps: deps()]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:logger]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    []
  end

  defp description() do
    "A few bits and bobs to work with Elixir, like erlang wrappers."
  end

  defp package() do
    [licenses: ["Apache-2.0"],
     links: %{"GitHub" => "https://github.com/JanHenryNystrom/jhn_elixir"}]
  end
end
