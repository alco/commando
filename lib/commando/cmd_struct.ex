defmodule Commando.Cmd do
  defstruct [
    name: nil,
    options: [],
    arguments: nil,
    subcmd: nil,
  ]
end
