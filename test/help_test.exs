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

    assert help_args([[name: "path", help: "Path to a directory."], [name: "port", required: false]]) == """
      Usage:
        tool <path> [<port>]

      Arguments:
        path      Path to a directory.
        port      (no documentation)
      """
  end

  test "just options" do
    assert help([
      name: "tool", options: [[name: :hi, help: "This is a hi option."]],
    ]) == """
      Usage:
        tool [options]

      Options:
        --hi=<hi>
          This is a hi option.
      """

    assert help([
      name: "tool", list_options: :all, options: [[name: :hi], [short: :h, help: "A short one."]],
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
      name: "tool", list_options: :all, options: [[name: :hi, short: :h],
                                                  [short: :p]],
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
      options: [[name: :hi, help: "This is an option."]],
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
      arguments: [[name: "arg1", help: "argument #1"], [name: "arg2", required: false]],
      options: [[short: :o, required: true, help: "Required option"]],
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
      options: [[name: :log, argtype: :boolean], [short: :v]],
      commands: [
        [name: "cmda",
         help: "This is command A. It is very practical",
         options: [[name: :opt_a, help: "Documented option"],
                   [name: :opt_b, required: true]]],

        [name: "cmdb",
         help: "Command B. Not so practical",
         options: [[short: :o], [short: :p]], arguments: [[]]],
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

    assert help(spec, "cmda") == """
      Usage:
        tool cmda [options]

      This is command A. It is very practical

      Options:
        --opt-a=<opt_a>
          Documented option

        --opt-b=<opt_b>
          (no documentation)
      """

    assert help(spec_all, "cmdb") == """
      Usage:
        tool cmdb [-o] [-p] <arg>

      Command B. Not so practical

      Options:
        -o
          (no documentation)

        -p
          (no documentation)

      Arguments:
        arg       (no documentation)
      """
  end

  test "custom help message" do
    spec = [
      name: "tool",
      help: {:full, """
        Usage: {{usage}}

        A very useful tool.

        Options (but not exactly):
          {{options}}

        Arguments:
        {{arguments}}

        Commands:
          {{commands}}
        """},
      options: [[name: :log, argtype: :boolean], [short: :v]],
      commands: [
        [name: "cmda",
         help: "This is command A. It is very practical",
         options: [[name: :opt_a, help: "Documented option"],
                   [name: :opt_b, required: true]]],

        [name: "cmdb",
         help: "Command B. Not so practical",
         options: [[short: :o], [short: :p]], arguments: [[]]],
      ],
    ]

    assert help(spec) == """
      Usage: tool [options] <command> [...]

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

  test "autohelp subcommand" do
    spec = [
      prefix: "pre",
      name: "tool",
      commands: [
        :help,
        [name: "cmda", options: [[name: :opt_a], [name: :opt_b, required: true]]],
        [name: "cmdb", options: [[short: :o], [short: :p]], arguments: [[]]],
      ],
    ]

    assert help(spec) == """
      Usage:
        pre tool <command> [...]

      Commands:
        help      Print description of the given command
        cmda      (no documentation)
        cmdb      (no documentation)
      """

    assert help(spec, "help") == """
      Usage:
        pre tool help [<command>]

      Print description of the given command.

      Arguments:
        command   The command to describe. When omitted, help for the tool itself is printed.
      """
  end

  defp help(opts, cmd \\ nil) do
    Commando.new(opts) |> Commando.help(cmd)
  end

  defp help_args(args) do
    Commando.new([name: "tool", arguments: args]) |> Commando.help()
  end
end
