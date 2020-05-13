##==============================================================================
## Copyright 2020 Jan Henry Nystrom <JanHenryNystrom@gmail.com>
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
## http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##==============================================================================
defmodule JhnElixir.MixProject do
  Module.register_attribute __MODULE__, :copyright, persist: true
  @copyright "(C) 2020, Jan Henry Nystrom <JanHenryNystrom@gmail.com>"
  use Mix.Project

  def project do
    [app: :jhn_elixir,
     version: "0.1.7",
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
    [{:ex_doc, "~> 0.14", only: :dev, runtime: false}]
  end

  defp description() do
    "A few bits and bobs to work with Elixir, like erlang wrappers."
  end

  defp package() do
    [licenses: ["Apache-2.0"],
     links: %{"GitHub" => "https://github.com/JanHenryNystrom/jhn_elixir"}]
  end
end
