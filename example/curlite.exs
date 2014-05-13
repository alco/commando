spec = [
  name: "curlite",
  help_option: :top_cmd,
  arguments: [[name: "url"]],
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
