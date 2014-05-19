spec = [
  name: "err",

  help_option: :top_cmd,
  list_options: :all,

  options: [
    :version,

    [name: "req",
     argtype: :integer],

    [short: "o"],
  ],

  arguments: [
    [name: "path"],
  ],
]

defmodule Errors do
  @moduledoc """
  Implementation of custom error formatting and overriding behaviour for --help
  and --version options.

  Example invocations to try:

      mix run example/err.exs

      mix run example/err.exs --req hi

      mix run example/err.exs / --req 13

  """

  @cmd_spec Commando.new(spec)

  def run() do
    case Commando.parse(@cmd_spec, on_error: :return, autoexec: false) do
      {:ok, cmd} ->
        IO.puts "Did successfully parse the invocation:"
        IO.inspect cmd

        # This needs to wait for an update in OptionParser
        #if cmd.options[:help] do
          #IO.puts "--> Pretending to print help"
        #end

        #if cmd.options[:version] do
          #IO.puts "--> Pretending to print version"
        #end

      {:error, reason} ->
        case reason do
          {:missing_arg, "path"} ->
            IO.puts "Got an error:"
            IO.puts "[error] Custom error message: missing required argument"

          _ ->
            IO.puts Commando.format_error(reason)
            IO.puts "Usage: " <> Commando.usage(@cmd_spec)
        end
    end
  end
end

Errors.run
