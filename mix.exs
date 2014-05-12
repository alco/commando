defmodule Commando.Mixfile do
  use Mix.Project

  def project do
    [app: :commando,
     version: "0.0.1",
     elixir: "~> 0.13.1",
     deps: deps]
  end

  def application do
    [applications: []]
  end

  defp deps do
    []
  end
end
