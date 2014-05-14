spec = [
  name: "curlite",
  version: "Long version string with\nnewlines.\ncurlite 1.0",

  help: {:full, """
    Usage: {{usage}}
    Options:
      {{options}}
    """},

  help_option: :top_cmd,

  arguments: [[name: "url"]],

  options: [
    {:version, :V},

    [name: "verbose", short: "v",
     valtype: :boolean,
     help: "Make the operation more talkative"],

    [name: "data", short: "d",
     argname: "DATA",
     help: "HTTP POST data"],

    [name: "data_binary",
     argname: "DATA",
     help: "HTTP POST binary data"],

    [name: "head", short: "I",
     valtype: :boolean,
     help: "Show document info only"],

    [name: "include", short: "i",
     valtype: :boolean,
     help: "Include protocol headers in the output"],
  ],
]

defmodule Curlite do
  @moduledoc """
  Implementation of a part of curl's command-line interface.

  Run it from the project root with `mix run`.

  Some examples:

      mix run example/curlite.exs -h

      mix run example/curlite.exs -i localhost

      mix run example/curlite.exs -v -I localhost

      mix run example/curlite.exs -v -i --data-binary @notes.txt http://localhost

  """

  {:ok, spec} = Commando.new(spec, autoexec: true, format_errors: true)
  @cmd_spec spec

  def run() do
    # Commando.parse parses System.argv by default
    %Commando.Cmd{
      options: opts,
      arguments: [addr],
    } = safe_exec(fn -> Commando.parse(@cmd_spec) end)

    process_command(opts, addr)
  end

  defp process_command(opts, addr) do
    IO.puts "Processing options"
    IO.puts "=================="
    default_opts = %{
      method: :get,
    }
    opts = safe_exec(fn -> Enum.reduce(opts, default_opts, &process_option/2) end)
    IO.puts "===done"

    IO.puts ""
    if opts[:verbose] do
      IO.puts "[verbose] ==> Making a '#{opts[:method]}' request to address #{addr}"
      if data=opts[:data] do
        IO.puts "[verbose] Request body: #{data}"
      end
      IO.puts ""

      IO.write "[verbose] Pretending to download something"
      Stream.repeatedly(fn ->
        IO.write "."
        :timer.sleep(300)
      end)
      |> Enum.take(10)
      IO.puts "done"

      IO.puts "[verbose] Pretending to have printed downloaded data."
    end

    if opts[:include_headers] do
      IO.puts "Fake-Header: fake_token"
      IO.puts "Server: remotely located"
      IO.puts "Date: today"
    end
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

  # We don't care about --help and --version here because they are handled
  # by Commando.parse()

  defp process_option({:include, true}, acc) do
    IO.puts "* I promise to include protocol headers in the output."
    Map.put(acc, :include_headers, true)
  end

  defp process_option({:head, true}, acc) do
    IO.puts "* Going to show document info only"
    Map.put(acc, :method, :head)
  end

  defp process_option({:verbose, true}, acc) do
    IO.puts "* Going to be more talkative"
    Map.put(acc, :verbose, true)
  end

  defp process_option({:data, "@"<>path}, acc) do
    IO.puts "* Reading ASCII data from file #{path}"
    post_data(acc, data_from_file(path))
  end

  defp process_option({:data, data}, acc) do
    post_data(acc, data)
  end

  defp process_option({:data_binary, "@"<>path}, acc) do
    IO.puts "* Reading BINARY data from file #{path}"
    post_data(acc, data_from_file(path))
  end

  defp process_option({:data_binary, data}, acc) do
    post_data(acc, data)
  end


  defp post_data(map, data) do
    Map.merge(map, %{data: data, method: :post})
  end

  defp data_from_file(path) do
    "<fake data from file #{path}>"
  end
end

Curlite.run
