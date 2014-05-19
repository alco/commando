# Scroll down for the description in moduledoc

inspect_path_help = """
  Send the contents of file at PATH in reponse to incoming requests.

  By default, nothing is sent in response, the connection is closed
  immediately.

  Passing a dash (-) for PATH will read from stdin.
  """

serve_list_help = """
  For directory requests, serve HTML with the list of contents of that
  directory.

  Without this option, "403 Forbidden" is returned for directory
  requests.
  """

commands = [
  :help,

  [name: "inspect",
   help: "Log incoming requests to stdout, optionally sending a reply back.",
   options: [
     [name: "reply_file", short: "f",
      argname: "path",
      help: inspect_path_help],
   ],
   action: &Mix.Tasks.Faketask.inspect/2],

  [name: "proxy",
   help: """
     Work as a tunnelling proxy, logging all communications. All traffic
     between client and remote server is transmitted without alterations. All
     requests and responses are logged to stdout.
     """,
   action: &Mix.Tasks.Faketask.proxy/2],

  [name: "serve",
   help: "Serve files from the specified directory, recursively.",
   arguments: [[name: "path", required: false, default: "."]],
   options: [
     [name: "list", short: "l",
      argtype: :boolean,
      help: serve_list_help],
   ],
   action: &Mix.Tasks.Faketask.serve/2],
]

spec = [
  prefix: "mix",
  name: "faketask",

  help: "Single task encapsulating a set of useful commands.",
  version: "faketask 1.2.3",

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
     default: "localhost",
     help: "Hostname to listen on. Accepts extended format with port, e.g. 'localhost:4000'."],

    [name: "port", short: "p",
     argtype: :integer,
     default: 1234,
     help: "Port number to listen on."],
  ],

  commands: commands,
]

defmodule Mix.Tasks.Faketask do
  use Mix.Task

  @shortdoc "Faketask using Commando"

  @moduledoc """
  Implementation of a Mix task demonstrating Commando's features.

  Run it from the project root. Examples:

      mix faketask

      mix faketask -p 13 --host 0.0.0.0 serve

      mix faketask inspect -f reply.txt

  """

  @cmd_spec Commando.new(spec)

  alias Commando.Cmd

  def run(args) do
    { :ok, %Cmd{options: opts} } = Commando.parse(args, @cmd_spec)

    # At this point cmd != nil and opts is a list.
    IO.puts ""
    IO.puts "Global options were:"
    IO.puts "  host: #{opts[:host]}"
    IO.puts "  port: #{opts[:port]}"
  end


  def inspect(%Cmd{options: opts}, %Cmd{options: _global_opts}) do
    if path=opts[:reply_file] do
      IO.puts "Will reply with data from file #{path}"
    end
    IO.puts "..."
    IO.puts "Done inspecting"
  end


  def proxy(%Cmd{}, %Cmd{options: _global_opts}) do
    IO.puts "..."
    IO.puts "Done proxying"
  end


  # we are sure that arguments==[path] because we provided a default value
  # for it
  def serve(%Cmd{arguments: %{"path" => path}}, %Cmd{options: _global_opts}) do
    IO.puts "Serving files from directory: #{path}"
    Stream.repeatedly(fn ->
      IO.write "."
      :timer.sleep(200)
    end)
    |> Enum.take(10)

    IO.puts "just kidding"
    IO.puts "Done serving"
  end
end
