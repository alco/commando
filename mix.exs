defmodule Commando.Mixfile do
  use Mix.Project

  def project do
    [app: :commando,
     version: "0.0.1",
     elixir: "~> 0.13.3 or ~> 0.14.0",
     elixirc_paths: ["lib", "example/mix"]]
  end

  def application do
    []
  end

  # no deps
  # --alco
end
