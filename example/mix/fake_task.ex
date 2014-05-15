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
   arguments: [[name: "path", optional: true, default: "."]],
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
     valtype: :integer,
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

  {:ok, spec} = Commando.new(spec)
  @cmd_spec spec

  def run(args) do
    config = [autoexec: true, format_errors: true]
    %Commando.Cmd{
      options: opts,
      subcmd: cmd,
    } = safe_exec(fn -> Commando.parse(@cmd_spec, config: config, args: args) end)

    # At this point cmd != nil and opts is a list.
    IO.puts "Global options:"
    IO.puts "  host: #{opts[:host]}"
    IO.puts "  port: #{opts[:port]}"

    IO.puts "Executing command '#{cmd.name}'...\n"
    exec_cmd(cmd)
  end


  defp exec_cmd(%{name: "inspect", options: opts}) do
    if path=opts[:reply_file] do
      IO.puts "Will reply with data from file #{path}"
    end
    IO.puts "..."
    IO.puts "Done inspecting"
  end


  defp exec_cmd(%{name: "proxy"}) do
    IO.puts "..."
    IO.puts "Done proxying"
  end


  # we are sure that arguments==[path] because we provided a default value
  # for it
  defp exec_cmd(%{name: "serve", arguments: [path]}) do
    IO.puts "Serving files from directory: #{path}"
    Stream.repeatedly(fn ->
      IO.write "."
      :timer.sleep(200)
    end)
    |> Enum.take(10)

    IO.puts "just kidding"
    IO.puts "Done serving"
  end


  defp safe_exec(f) do
    try do
      f.()
    rescue
      e in [RuntimeError] ->
        IO.puts e.message
        System.halt(1)
    end
  end
end
