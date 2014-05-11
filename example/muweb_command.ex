commands = [
#  [name: "help",
#    help: "Display description of the given command.",
#    arguments: [[name: "[command]"]],
#  ],

  [name: "inspect",
    help: "Log incoming requests to stdout, optionally sending a reply back.",
    options: [
      [name: "reply_file", short: "f",
       argname: "path",
       help: """
         Send the contents of file at PATH in reponse to incoming requests.

         By default, nothing is sent in response, the connection is closed immediately.

         Passing a dash (-) for PATH will read from stdin.
         """],
    ],
  ],

  [name: "proxy",
    help: "Work as a proxy, transmiting all traffic between client and remote server without alterations, but logging all requests and responses to stdout.",
  ],

  [name: "serve",
    help: "Serve files from the specified directory, recursively.",
    arguments: [[name: "[path]"]],
    options: [
      [name: "list", short: "l",
       help: """
         For directory requests, serve HTML with the list of contents of that directory.

         Without this option, "403 Forbidden" is returned for directory requests.
         """],
    ],
  ],
]

spec = Commando.new [
  width: 80,

  usage: """
    Usage:
      mix muweb [options] <command> [<args>]

    Single task encapsulating a set of useful commands that utilise the μWeb server.

    Options (available for all commands except "help"):
      {{options}}

    Commands:
      {{commands}}
    """,

  options: [
    [name: "host", short: "h",
     argname: "hostname",
     help: "Hostname to listen on. Accepts extended format with port, e.g. 'localhost:4000'."],

    [name: "port", short: "p",
     #argname: "port",
     help: "Port number to listen on."],
  ],

  commands: commands,
]

defmodule MuWebCommand do
  @cmd_spec spec

  def run(args) do
    {opts, args} = parse_args(args)
  end

  defp parse_args(args) do
    IO.inspect @cmd_spec
    case Commando.parse(@cmd_spec, args) do
      {:error, reason} ->
        IO.puts "Error while parsing arguments: #{reason}"
    end
  end
end
