spec = [
  name: "curlite",
  version: "Long version string with\nnewlines.\n1.0",

  help: {:full, """
    Usage: {{usage}}
    Options:
      {{options}}
    """},

  help_option: :top_cmd,

  arguments: [[name: "url"]],

  options: [
    {:version, :V},
    [name: "data", short: "d", help: "Request body. Implies POST method"],
  ],
]

defmodule Curlite do
  @moduledoc """
  Implementation of a part of curl's command-line interface.

  Run it from the project root as

      mix run example/curlite.exs

  """

  @cmd_spec Commando.new(spec, autoexec: true)

  def run() do
    # Commando.parse parses System.argv by default
    IO.inspect Commando.parse(@cmd_spec)
  end
end

Curlite.run
