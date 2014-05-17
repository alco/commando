defmodule CommandoTest.ParseTest do
  use ExUnit.Case

  alias Commando.Cmd

  test "basic command" do
    assert parse([name: "tool"], []) == {:ok, %Cmd{
      name: "tool", options: [], arguments: [], subcmd: nil
    }}
  end

  test "return errors" do
    spec = [name: "tool", arguments: []]
    assert parse(spec, ["hello"], [on_error: :return])
           == {:error, {:bad_arg, "hello"}}
  end

  test "raise errors" do
    spec = [name: "tool", arguments: []]
    msg = "Unexpected argument: hello"
    assert_raise RuntimeError, msg, fn ->
      parse(spec, ["hello"], [on_error: :raise])
    end
  end

  test "just arguments" do
    spec = [name: "tool", arguments: []]
    assert parse(spec, []) == {:ok, %Cmd{
      name: "tool", options: [], arguments: [], subcmd: nil
    }}

    spec = [name: "tool", arguments: []]
    assert_raise RuntimeError, "Unexpected argument: hello", fn ->
      parse(spec, ["hello"])
    end

    spec = [name: "tool", arguments: [[name: "path", required: false]]]
    assert parse(spec, []) == {:ok, %Cmd{
      name: "tool", options: [], arguments: [], subcmd: nil
    }}
    assert parse(spec, ["hi"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: ["hi"], subcmd: nil
    }}

    spec = [name: "tool", arguments: [[name: "path"]]]
    assert_raise RuntimeError, "Missing required argument: <path>", fn ->
      parse(spec, [])
    end
    assert parse(spec, ["hi"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: ["hi"], subcmd: nil
    }}
    assert_raise RuntimeError, "Unexpected argument: world", fn ->
      parse(spec, ["hello", "world"])
    end

    spec = [name: "tool", arguments: [[name: "path"], [name: "port", required: false]]]
    assert_raise RuntimeError, "Missing required argument: <path>", fn ->
      parse(spec, [])
    end
    assert parse(spec, ["home"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: ["home"], subcmd: nil
    }}
    assert parse(spec, ["home", "extra"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: ["home", "extra"], subcmd: nil
    }}
    assert_raise RuntimeError, "Unexpected argument: more", fn ->
      parse(spec, ["home", "extra", "more"])
    end
  end

  test "just options" do
    spec = [name: "tool", options: [[name: "hi"]]]
    assert parse(spec, []) == {:ok, %Cmd{
      name: "tool", options: [], arguments: [], subcmd: nil
    }}
    assert parse(spec, ["--hi=hello"]) == {:ok, %Cmd{
      name: "tool", options: [hi: "hello"], arguments: [], subcmd: nil
    }}
    assert parse(spec, ["--hi", "hello"]) == {:ok, %Cmd{
      name: "tool", options: [hi: "hello"], arguments: [], subcmd: nil
    }}
    assert_raise RuntimeError, "Missing argument for option: --hi", fn ->
      parse(spec, ["--hi"])
    end
    assert_raise RuntimeError, "Unrecognized option: --bye", fn ->
      parse(spec, ["--bye"])
    end
    assert_raise RuntimeError, "Unrecognized option: --bye", fn ->
      parse(spec, ["--bye", "hello"])
    end

    spec = [name: "tool", options: [[name: "hi", required: true]]]
    assert_raise RuntimeError, "Missing required option: --hi", fn ->
      parse(spec, [])
    end
    assert_raise RuntimeError, "Missing required option: --hi", fn ->
      parse(spec, ["hello"])
    end
    assert_raise RuntimeError, "Missing argument for option: --hi", fn ->
      parse(spec, ["--hi"])
    end
    assert parse(spec, ["--hi=hello"]) == {:ok, %Cmd{
      name: "tool", options: [hi: "hello"], arguments: [], subcmd: nil
    }}

    spec = [name: "tool", options: [[name: "hi", valtype: :integer]]]
    assert_raise RuntimeError, "Missing argument for option: --hi", fn ->
      parse(spec, ["--hi"])
    end
    assert_raise RuntimeError, "Bad option value for --hi: hello", fn ->
      parse(spec, ["--hi=hello"])
    end
    assert parse(spec, ["--hi", "13"]) == {:ok, %Cmd{
      name: "tool", options: [hi: 13], arguments: [], subcmd: nil
    }}

    spec = [name: "tool", options: [[name: "hi", valtype: :boolean]]]
    assert_raise RuntimeError, "Bad option value for --hi: hello", fn ->
      parse(spec, ["--hi=hello"])
    end
    assert parse(spec, ["--hi"]) == {:ok, %Cmd{
      name: "tool", options: [hi: true], arguments: [], subcmd: nil
    }}
    assert parse(spec, ["--no-hi"]) == {:ok, %Cmd{
      name: "tool", options: [hi: false], arguments: [], subcmd: nil
    }}
  end

  test "defaults for options" do
    spec = [name: "tool", arguments: [[required: false]], options: [
      [name: "host", short: "h", default: "localhost"],
      [name: "port", short: "p", valtype: :integer, default: 1234],
    ]]

    assert parse(spec, []) == {:ok, %Cmd{
      name: "tool", options: [host: "localhost", port: 1234], arguments: [], subcmd: nil
    }}
    assert parse(spec, ["--port=12"]) == {:ok, %Cmd{
      name: "tool", options: [port: 12, host: "localhost"], arguments: [], subcmd: nil
    }}
    assert parse(spec, ["-h", "..."]) == {:ok, %Cmd{
      name: "tool", options: [host: "...", port: 1234], arguments: [], subcmd: nil
    }}
  end

  test ":overwrite modifier for options" do
    spec = [name: "tool", arguments: [[required: false]], options: [
      [name: "mercury", valtype: :boolean, multival: :overwrite],
    ]]

    assert parse(spec, ["--mercury"]) == {:ok, %Cmd{
      name: "tool", options: [mercury: true], arguments: [], subcmd: nil
    }}
    assert parse(spec, ["--mercury", "--mercury=false"]) == {:ok, %Cmd{
      name: "tool", options: [mercury: false], arguments: [], subcmd: nil
    }}
    assert parse(spec, ["--no-mercury", "--mercury"]) == {:ok, %Cmd{
      name: "tool", options: [mercury: true], arguments: [], subcmd: nil
    }}
    assert parse(spec, ["--no-mercury", "--mercury", "foo"]) == {:ok, %Cmd{
      name: "tool", options: [mercury: true], arguments: ["foo"], subcmd: nil
    }}
  end

  test ":keep modifier for options" do
    spec = [name: "tool", arguments: [[required: false]], options: [
      [name: "mercury", valtype: :boolean, multival: :overwrite],
      [name: "venus", valtype: :integer, multival: :keep],
    ]]

    assert parse(spec, ["--venus=13"]) === {:ok, %Cmd{
      name: "tool", options: [venus: 13], arguments: [], subcmd: nil
    }}
    assert parse(spec, ["--venus", "13", "--venus=0"]) === {:ok, %Cmd{
      name: "tool", options: [venus: 13, venus: 0], arguments: [], subcmd: nil
    }}
    assert parse(spec, ["--venus=13", "--mercury", "--venus", "4"]) === {:ok, %Cmd{
      name: "tool", options: [venus: 13, mercury: true, venus: 4], arguments: [], subcmd: nil
    }}
  end

  test ":accumulate modifier for options" do
    spec = [name: "tool", arguments: [[required: false]], options: [
      [name: "venus", valtype: :integer, multival: :keep],
      [name: "earth", valtype: :float, multival: :accumulate],
    ]]

    assert parse(spec, ["--earth=13"]) === {:ok, %Cmd{
      name: "tool", options: [earth: [13.0]], arguments: [], subcmd: nil
    }}
    assert parse(spec, ["--earth", "13", "--earth=0"]) === {:ok, %Cmd{
      name: "tool", options: [earth: [13.0, 0.0]], arguments: [], subcmd: nil
    }}
    assert parse(spec, ["--earth=13", "--venus", "11", "--earth", "4"]) === {:ok, %Cmd{
      name: "tool", options: [earth: [13.0, 4.0], venus: 11], arguments: [], subcmd: nil
    }}
  end

  test ":error modifier for options" do
    spec = [name: "tool", arguments: [[required: false]], options: [
      [name: "earth", valtype: :float, multival: :accumulate],
      [name: "mars", valtype: :string, multival: :error],
    ]]

    assert parse(spec, ["--mars=13"]) == {:ok, %Cmd{
      name: "tool", options: [mars: "13"], arguments: [], subcmd: nil
    }}
    msg = "Error trying to overwrite the value for option --mars"
    assert_raise RuntimeError, msg, fn ->
      parse(spec, ["--mars", "hi", "--mars=bye"])
    end
    assert_raise RuntimeError, msg, fn ->
      parse(spec, ["--mars=hi", "--earth=1", "--mars", "bye"])
    end
  end


  test "options and arguments" do
    spec = [name: "tool", arguments: [
      [name: "path"],
      [name: "port", required: false]
    ], options: [
      [name: "earth", valtype: :float],
      [name: "mars", valtype: :string],
      [short: "o", valtype: :string, required: true],
    ]]

    assert_raise RuntimeError, "Missing required argument: <path>", fn ->
      parse(spec, ["-o", "1"])
    end
    assert_raise RuntimeError, "Missing required option: -o", fn ->
      parse(spec, ["foo"])
    end
    assert parse(spec, ["-o", "home", "path", "port"]) == {:ok, %Cmd{
      name: "tool", options: [o: "home"], arguments: ["path", "port"], subcmd: nil
    }}
    assert parse(spec, ["-o", ".", "home", "--earth=13"]) == {:ok, %Cmd{
      name: "tool", options: [o: ".", earth: 13.0], arguments: ["home"], subcmd: nil
    }}
  end

  test "subcommands" do
    spec = [
      name: "tool",
      options: [[name: "log", valtype: :boolean], [short: "v"]],
      commands: [
        [name: "cmda", options: [[name: "opt_a"], [name: "opt_b", required: true]]],
        [name: "cmdb", options: [[short: "v"], [short: "p"]], arguments: [[]]],
      ],
    ]

    assert_raise RuntimeError, "Missing command", fn ->
      parse(spec, [])
    end
    assert_raise RuntimeError, "Unrecognized command: hello", fn ->
      parse(spec, ["--log", "-v", ".", "hello"]) |> IO.inspect
    end
    assert_raise RuntimeError, "Missing required option: --opt-b", fn ->
      parse(spec, ["--log", "-v", ".", "cmda"])
    end

    assert parse(spec, ["--log", "-v", ".", "cmda", "--opt-b=0"]) == {:ok, %Cmd{
      name: "tool", options: [log: true, v: "."], arguments: nil, subcmd: %Cmd{
        name: "cmda", options: [opt_b: "0"], arguments: [], subcmd: nil
      }
    }}

    assert_raise RuntimeError, "Unrecognized option: --opt-b", fn ->
      parse(spec, ["cmdb", "--opt-b=0"])
    end

    assert_raise RuntimeError, "Missing required argument: <arg>", fn ->
      parse(spec, ["cmdb"])
    end

    assert parse(spec, ["cmdb", "hello"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: nil, subcmd: %Cmd{
        name: "cmdb", options: [], arguments: ["hello"], subcmd: nil
      }
    }}

    assert parse(spec, ["-v", "0", "cmdb", "-v", "1", "hello", "-p", "2"]) == {:ok, %Cmd{
      name: "tool", options: [v: "0"], arguments: nil, subcmd: %Cmd{
        name: "cmdb", options: [v: "1", p: "2"], arguments: ["hello"], subcmd: nil
      }
    }}
  end

  @tag slowpoke: true
  test "autohelp subcommand" do
    spec = [
      name: "tool",
      commands: [
        :help,
      ],
    ]

    assert parse(spec, ["help"], autoexec: false) == {:ok, %Cmd {
      name: "tool", options: [], arguments: nil, subcmd: %Cmd {
        name: "help", options: [], arguments: [], subcmd: nil
      }
    }}

    assert parse(spec, ["help", "bad"], autoexec: false) == {:ok, %Cmd {
      name: "tool", options: [], arguments: nil, subcmd: %Cmd {
        name: "help", options: [], arguments: ["bad"], subcmd: nil
      }
    }}

    expected = """
      Usage:
        tool [-v|--verbose] [-d] <command> [...]

      A very practical tool.

      Options:
        -v, --verbose
          (no documentation)

        -d
          (no documentation)

      Commands:
        help      Print description of the given command
        cmd       (no documentation)

      """

    # Precompile so that mix output doesn't interfere with the script output
    System.cmd("mix compile")

    assert run_test_cmd([]) == expected

    assert run_test_cmd(["help"]) == expected

    assert run_test_cmd(["help", "help"]) == """
      Usage:
        tool help [<command>]

      Print description of the given command.

      Arguments:
        command   The command to describe. When omitted, help for the tool itself is printed.

      """

    assert run_test_cmd(["help", "cmd"]) == """
      Usage:
        tool cmd --opt=<opt> [-f|--foo] [<arg>]

      Options:
        --opt=<opt>
          (no documentation)

        -f, --foo
          (no documentation)

      Arguments:
        arg       (no documentation)

      """

    assert run_test_cmd(["help", "bad"]) == "Unrecognized command: bad\n"
  end


  defp parse(spec, args, config \\ [on_error: :raise]) do
    spec = Commando.new(spec)
    Commando.parse(args, spec, config)
  end

  defp run_test_cmd(args) do
    argstr = Enum.join(args, " ")
    System.cmd("mix run test/fixtures/help_cmd.exs #{argstr}")
  end

  #defp run_test_cmd(args) do
    #import ExUnit.CaptureIO
    #capture_io(fn ->
      #try do
        #Mix.Task.run("run", ["test/fixtures/help_cmd.exs"|args])
        #raise RuntimeError, message: "Did not receive proper exit from run"
      #catch
        #:exit, {Commando, 0} ->
          #Code.unload_files(["test/fixtures/help_cmd.exs"])
          #Mix.Task.reenable("run")
      #end
    #end)
  #end
end
