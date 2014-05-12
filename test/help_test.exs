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
        arg       (no documentation)
      """

    assert help_args([[name: "path"]]) == """
      Usage:
        tool <path>

      Arguments:
        path      (no documentation)
      """

    assert help_args([[name: "path", help: "Path to a directory."], [name: "port", optional: true]]) == """
      Usage:
        tool <path> [<port>]

      Arguments:
        path      Path to a directory.
        port      (no documentation)
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
      name: "tool", list_options: :all, options: [[name: "hi"], [short: "h", help: "A short one."]],
    ]) == """
      Usage:
        tool [--hi=<hi>] [-h]

      Options:
        --hi=<hi>
          (no documentation)

        -h
          A short one.
      """

    assert help([
      name: "tool", list_options: :all, options: [[name: "hi", short: "h"],
                                                  [short: "p"]],
    ]) == """
      Usage:
        tool [-h <hi>|--hi=<hi>] [-p]

      Options:
        -h <hi>, --hi=<hi>
          (no documentation)

        -p
          (no documentation)
      """
  end

  test "options and arguments" do
    assert help([
      name: "tool",
      arguments: [[help: "An argument. Second sentence."]],
      options: [[name: "hi", help: "This is an option."]],
    ]) == """
      Usage:
        tool [options] <arg>

      Options:
        --hi=<hi>
          This is an option.

      Arguments:
        arg       An argument. Second sentence.
      """

    assert help([
      name: "tool",
      arguments: [[name: "arg1", help: "argument #1"], [name: "arg2", optional: true]],
      options: [[short: "o", required: true, help: "Required option"]],
      list_options: :all,
    ]) == """
      Usage:
        tool -o <arg1> [<arg2>]

      Options:
        -o
          Required option

      Arguments:
        arg1      argument #1
        arg2      (no documentation)
      """
  end

  test "proper indentation" do
  end

  test "subcommands" do
    spec = [
      name: "tool",
      options: [[name: "log", kind: :boolean], [short: "v"]],
      commands: [
        [name: "cmda",
         help: "This is command A. It is very practical",
         options: [[name: "opt_a", help: "Documented option"],
                   [name: "opt_b", required: true]]],

        [name: "cmdb",
         help: "Command B. Not so practical",
         options: [[short: "o"], [short: "p"]], arguments: [[]]],
      ],
    ]
    spec_all = [list_options: :all] ++ spec

    assert help(spec) == """
      Usage:
        tool [options] <command> [...]

      Options:
        --log
          (no documentation)

        -v
          (no documentation)

      Commands:
        cmda      This is command A
        cmdb      Command B
      """

    #assert help(spec, "cmda") == "tool cmda [options]"
    #assert help(spec_all, "cmda") == "tool cmda [--opt-a=<opt_a>] --opt-b=<opt_b>"

    #assert help(spec, "cmdb") == "tool cmdb [options] <arg>"
    #assert help(spec_all, "cmdb") == "tool cmdb [-o] [-p] <arg>"
  end

  test "custom help message" do
    spec = [
      name: "tool",
      help: {:full, """
        Usage: ...

        A very useful tool.

        Options (but not exactly):
        {{options}}

        Arguments:
        {{arguments}}

        Commands:
        {{commands}}
        """},
      options: [[name: "log", kind: :boolean], [short: "v"]],
      commands: [
        [name: "cmda",
         help: "This is command A. It is very practical",
         options: [[name: "opt_a", help: "Documented option"],
                   [name: "opt_b", required: true]]],

        [name: "cmdb",
         help: "Command B. Not so practical",
         options: [[short: "o"], [short: "p"]], arguments: [[]]],
      ],
    ]

    assert help(spec) == """
      Usage: ...

      A very useful tool.

      Options (but not exactly):
        --log
          (no documentation)

        -v
          (no documentation)

      Arguments:


      Commands:
        cmda      This is command A
        cmdb      Command B
      """
  end

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
