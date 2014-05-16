spec = [
  name: "err",

  options: [
    [name: "req",
     required: true],

    [short: "v"],
  ],

  arguments: [
    [name: "path"],
  ],
]

defmodule Errors do
  @moduledoc """
  Implementation of custom error formatting and overriding behaviour for help
  command, --help and --version options.

  Example invocations to try:

      mix run example/err.exs

      mix run example/err.exs --req hi

      mix run example/err.exs / --req bye

  """

  @cmd_spec Commando.new(spec)

  def run() do
    case Commando.parse(@cmd_spec, on_error: :return) do
      {:ok, cmd} ->
        IO.puts "Did successfully parse the invocation:"
        IO.inspect cmd

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
