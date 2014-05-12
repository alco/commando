defmodule CommandoTest.HelpTest do
  use ExUnit.Case

  test "basic command" do
    assert help(name: "tool") == """
      Usage:
        tool

      """

    assert help(name: "tool", help: "This is a useful tool.") == """
      Usage:
        tool

      This is a useful tool.
      """

    assert help(name: "tool", help: {:full, "This is a useful tool."})
           == "This is a useful tool."
  end

  test "just arguments" do
    assert help_args([[]]) == """
      Usage:
        tool <arg>

      Arguments:
        arg     (no documentation)
      """

    assert help_args([[name: "path"]]) == """
      Usage:
        tool <path>

      Arguments:
        path    (no documentation)
      """

    assert help_args([[name: "path", help: "Path to a directory."], [name: "port", optional: true]]) == """
      Usage:
        tool <path> [<port>]

      Arguments:
        path    Path to a directory.
        port    (no documentation)
      """
  end

  test "just options" do
    assert help([
      name: "tool", options: [[name: "hi", help: "This is a hi option."]],
    ]) == """
    Usage:
      tool [options]

    Options:
      --hi=<hi>
        This is a hi option.
    """

    assert help([
      name: "tool", list_options: :all, options: [[name: "hi"], [short: "h"]],
    ]) == "tool [-h]"

    assert help([
      name: "tool", list_options: :all, options: [[name: "hi", short: "h"],
                                                  [short: "p"]],
    ]) == "tool [--hi=<hi>]"
  end

  #test "options and arguments" do
    #assert help([
      #name: "tool",
      #arguments: [[]],
      #options: [[name: "hi"]],
    #]) == "tool [options] <arg>"

    #assert help([
      #name: "tool",
      #arguments: [[name: "arg1"], [name: "arg2", optional: true]],
      #options: [[name: "hi"], [short: "h", argname: "value"]],
      #list_options: :all,
    #]) == "tool [--hi=<hi>] [-h <value>] <arg1> [<arg2>]"
  #end

  #test "command with prefix" do
    #prefix = [prefix: "prefix", name: "tool"]

    #cmd = Commando.new prefix
    #assert Commando.help(cmd) |> String.strip == "prefix tool"

    #cmd = Commando.new prefix ++ [arguments: [[name: "hi"]]]
    #assert Commando.help(cmd) |> String.strip == "prefix tool <hi>"

    #cmd = Commando.new prefix ++ [options: [[name: "hi"]], list_options: :long]
    #assert Commando.help(cmd) |> String.strip == "prefix tool [--hi=<hi>]"
  #end

  #test "subcommands" do
    #spec = [
      #name: "tool",
      #options: [[name: "log", kind: :boolean], [short: "v"]],
      #commands: [
        #[name: "cmda", options: [[name: "opt_a"], [name: "opt_b", required: true]]],
        #[name: "cmdb", options: [[short: "o"], [short: "p"]], arguments: [[]]],
      #],
    #]
    #spec_all = [list_options: :all] ++ spec

    #assert help(spec) == "tool [options] <command> [...]"
    #assert help(spec_all) == "tool [--log] [-v] <command> [...]"
    #assert help(spec_all) == "tool [--log] [-v] <command> [...]"

    #assert help(spec, "cmda") == "tool cmda [options]"
    #assert help(spec_all, "cmda") == "tool cmda [--opt-a=<opt_a>] --opt-b=<opt_b>"

    #assert help(spec, "cmdb") == "tool cmdb [options] <arg>"
    #assert help(spec_all, "cmdb") == "tool cmdb [-o] [-p] <arg>"
  #end

  #test "autohelp subcommand" do
    #spec = [
      #name: "tool",
      #options: [[name: "log", kind: :boolean], [short: "v"]],
      #commands: [
        #:help,
        #[name: "cmda", options: [[name: "opt_a"], [name: "opt_b", required: true]]],
        #[name: "cmdb", options: [[short: "o"], [short: "p"]], arguments: [[]]],
      #],
    #]

    #assert help(spec, "help") == "tool help [<command>]"
  #end

  defp help(opts, cmd \\ nil),
    do: Commando.new(opts) |> Commando.help(cmd)

  defp help_args(args),
    do: Commando.new([name: "tool", arguments: args]) |> Commando.help
end
