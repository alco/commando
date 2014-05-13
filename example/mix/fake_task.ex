# Scroll down for the description in moduledoc

commands = [
  :help,

  [name: "inspect",
   help: "Log incoming requests to stdout, optionally sending a reply back.",
   options: [
     [name: "reply_file", short: "f",
      argname: "path",
      help: """
        Send the contents of file at PATH in reponse to incoming requests.

        By default, nothing is sent in response, the connection is closed
        immediately.

        Passing a dash (-) for PATH will read from stdin.
        """],
   ]],

  [name: "proxy",
   help: """
     Work as a tunnelling proxy, logging all communications. All traffic
     between client and remote server is transmitted without alterations. All
     requests and responses are logged to stdout.
     """,
  ],

  [name: "serve",
   help: "Serve files from the specified directory, recursively.",
   arguments: [[name: "path", optional: true]],
   options: [
     [name: "list", short: "l",
      valtype: :boolean,
      help: """
        For directory requests, serve HTML with the list of contents of that
        directory.

        Without this option, "403 Forbidden" is returned for directory
        requests.
        """],
   ]],
]

spec = [
  prefix: "mix",
  name: "faketask",

  help: "Single task encapsulating a set of useful commands.",
  version: "1.2.3",

  # We could provide a custom message by passing a tuple {:full, <string>}
#  help: {:full, """
#    Usage:
#      {{usage}}
#
#    Single task encapsulating a set of useful commands.
#
#    Options (available for all commands except "help"):
#    {{options}}
#
#    Commands:
#    {{commands}}
#    """},

  list_options: :short,

  options: [
    :version,

    [name: "host", short: "h",
     argname: "hostname",
     help: "Hostname to listen on. Accepts extended format with port, e.g. 'localhost:4000'."],

    [name: "port", short: "p",
     valtype: :integer,
     help: "Port number to listen on."],
  ],

  commands: commands,
]

defmodule Mix.Tasks.Faketask do
  use Mix.Task

  @shortdoc "Faketask using Commando"

  @moduledoc """
  Implementation of a Mix task demonstrating Commando's features.

  Run it from the project root as

      mix faketask

  """

  @cmd_spec Commando.new(spec, autoexec: true)

  def run(args) do
    IO.inspect Commando.parse(@cmd_spec, args)
  end
end
