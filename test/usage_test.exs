defmodule CommandoTest.UsageTest do
  use ExUnit.Case

  test "basic command" do
    assert usage(name: "tool") == "tool"
  end

  test "just arguments" do
    assert usage_args([[]]) == "tool <arg>"
    assert usage_args([[name: "path"]]) == "tool <path>"
    assert usage_args([[name: "path", optional: true]]) == "tool [<path>]"
    assert usage_args([[name: "path"], [name: "port", optional: true]])
           == "tool <path> [<port>]"
  end

  test "just options" do
    assert usage([
      name: "tool", options: [[name: "hi"]],
    ]) == "tool [options]"

    assert usage([
      name: "tool", list_options: :short, options: [[name: "hi"]],
    ]) == "tool"

    assert usage([
      name: "tool", list_options: :long, options: [[short: "h"]],
    ]) == "tool"

    assert usage([
      name: "tool", list_options: :short, options: [[name: "hi"], [short: "h"]],
    ]) == "tool [-h]"

    assert usage([
      name: "tool", list_options: :long, options: [[name: "hi"], [short: "h"]],
    ]) == "tool [--hi=<hi>]"

    assert usage([
      name: "tool", list_options: :all, options: [[name: "hi"], [short: "h"]],
    ]) == "tool [--hi=<hi>] [-h]"

    assert usage([
      name: "tool", list_options: :all, options: [[name: "hi", short: "h"]],
    ]) == "tool [-h <hi>|--hi=<hi>]"

    assert usage([
      name: "tool", list_options: :all,
      options: [[name: "hi", short: "h", kind: :boolean]],
    ]) == "tool [-h|--hi]"

    assert usage([
      name: "tool", list_options: :short,
      options: [[name: "hi", short: "h", kind: :boolean, required: true]],
    ]) == "tool -h"

    assert usage([
      name: "tool", list_options: :long,
      options: [[name: "hi", short: "h", kind: :boolean, required: true]],
    ]) == "tool --hi"

    assert usage([
      name: "tool", list_options: :all,
      options: [[name: "hi", short: "h", kind: :boolean, required: true]],
    ]) == "tool {-h|--hi}"
  end

  test "options and arguments" do
    assert usage([
      name: "tool",
      arguments: [[]],
      options: [[name: "hi"]],
    ]) == "tool [options] <arg>"

    assert usage([
      name: "tool",
      arguments: [[name: "arg1"], [name: "arg2", optional: true]],
      options: [[name: "hi"], [short: "h", argname: "value"]],
      list_options: :all,
    ]) == "tool [--hi=<hi>] [-h <value>] <arg1> [<arg2>]"
  end

  test "command with prefix" do
    prefix = [prefix: "prefix", name: "tool"]

    cmd = Commando.new prefix
    assert Commando.usage(cmd) |> String.strip == "prefix tool"

    cmd = Commando.new prefix ++ [arguments: [[name: "hi"]]]
    assert Commando.usage(cmd) |> String.strip == "prefix tool <hi>"

    cmd = Commando.new prefix ++ [options: [[name: "hi"]], list_options: :long]
    assert Commando.usage(cmd) |> String.strip == "prefix tool [--hi=<hi>]"
  end

  test "subcommands" do
    spec = [
      name: "tool",
      options: [[name: "log", kind: :boolean], [short: "v"]],
      commands: [
        [name: "cmda", options: [[name: "opt_a"], [name: "opt_b", required: true]]],
        [name: "cmdb", options: [[short: "o"], [short: "p"]], arguments: [[]]],
      ],
    ]
    spec_all = [list_options: :all] ++ spec

    assert usage(spec) == "tool [options] <command> [...]"
    assert usage(spec_all) == "tool [--log] [-v] <command> [...]"
    assert usage(spec_all) == "tool [--log] [-v] <command> [...]"

    assert usage(spec, "cmda") == "tool cmda [options]"
    assert usage(spec_all, "cmda") == "tool cmda [--opt-a=<opt_a>] --opt-b=<opt_b>"

    assert usage(spec, "cmdb") == "tool cmdb [options] <arg>"
    assert usage(spec_all, "cmdb") == "tool cmdb [-o] [-p] <arg>"
  end

  test "autohelp subcommand" do
    spec = [
      name: "tool",
      options: [[name: "log", kind: :boolean], [short: "v"]],
      commands: [
        :help,
        [name: "cmda", options: [[name: "opt_a"], [name: "opt_b", required: true]]],
        [name: "cmdb", options: [[short: "o"], [short: "p"]], arguments: [[]]],
      ],
    ]

    assert usage(spec, "help") == "tool help [<command>]"
  end

  defp usage(opts, cmd \\ nil),
    do: Commando.new(opts) |> Commando.usage(cmd) |> String.strip

  defp usage_args(args),
    do: Commando.new([name: "tool", arguments: args]) |> Commando.usage |> String.strip
end
