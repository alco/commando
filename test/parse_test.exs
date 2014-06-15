defmodule CommandoTest.ParseTest do
  use ExUnit.Case

  alias Commando.Cmd

  test "basic command" do
    assert parse([name: "tool"], []) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{}, subcmd: nil
    }}
  end

  test "return errors" do
    spec = [name: "tool", arguments: []]
    assert parse(spec, ["hello"])
           == {:error, {:bad_arg, "hello"}}
  end

  test "raise errors" do
    spec = [name: "tool", arguments: []]
    msg = "Unexpected argument: hello"
    assert_raise RuntimeError, msg, fn ->
      exec(spec, ["hello"], [on_error: :raise])
    end
  end

  test "just arguments" do
    spec = [name: "tool", arguments: []]
    assert parse(spec, []) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{}, subcmd: nil
    }}

    spec = [name: "tool", arguments: []]
    assert_raise RuntimeError, "Unexpected argument: hello", fn ->
      exec(spec, ["hello"])
    end

    spec = [name: "tool", arguments: [[name: "path", required: false]]]
    assert parse(spec, []) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["hi"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{"path" =>"hi"}, subcmd: nil
    }}

    spec = [name: "tool", arguments: [[name: "path"]]]
    assert_raise RuntimeError, "Missing required argument: <path>", fn ->
      exec(spec, [])
    end
    assert parse(spec, ["hi"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{"path" => "hi"}, subcmd: nil
    }}
    assert_raise RuntimeError, "Unexpected argument: world", fn ->
      exec(spec, ["hello", "world"])
    end

    spec = [name: "tool", arguments: [[name: "path"], [name: "port", required: false]]]
    assert_raise RuntimeError, "Missing required argument: <path>", fn ->
      exec(spec, [])
    end
    assert parse(spec, ["home"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{"path" => "home"}, subcmd: nil
    }}
    assert parse(spec, ["home", "extra"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{"path" => "home", "port" => "extra"}, subcmd: nil
    }}
    assert_raise RuntimeError, "Unexpected argument: more", fn ->
      exec(spec, ["home", "extra", "more"])
    end
  end

  test "vararg" do
    spec = [name: "tool", arguments: [
      [name: "o1", required: false],
      [name: "o2", required: false],
      [name: "r1"],
      [name: "r2"],
      [name: "r3", nargs: :inf],
    ]]
    assert_raise RuntimeError, "Missing required argument: <r1>", fn ->
      exec(spec, [])
    end
    assert_raise RuntimeError, "Missing required argument: <r2>", fn ->
      exec(spec, ["a"])
    end
    assert_raise RuntimeError, "Missing required argument: <r3>", fn ->
      exec(spec, ["a", "b"])
    end
    assert parse(spec, ["a", "b", "c"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{
        "r1" => "a", "r2" => "b", "r3" => ["c"]
      }, subcmd: nil
    }}
    assert parse(spec, ["a", "b", "c", "d"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{
        "o1" => "a", "r1" => "b", "r2" => "c", "r3" => ["d"]
      }, subcmd: nil
    }}
    assert parse(spec, ["a", "b", "c", "d", "e"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{
        "o1" => "a", "o2" => "b", "r1" => "c", "r2" => "d", "r3" => ["e"]
      }, subcmd: nil
    }}
    assert parse(spec, ["a", "b", "c", "d", "e", "f"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{
        "o1" => "a", "o2" => "b", "r1" => "c", "r2" => "d", "r3" => ["e", "f"]
      }, subcmd: nil
    }}
  end

  test "vararg star" do
    spec = [name: "tool", arguments: [
      [name: "o1", required: false],
      [name: "o2", required: false],
      [name: "r1"],
      [name: "r2"],
      [name: "r3", nargs: :inf, required: false],
    ]]
    assert_raise RuntimeError, "Missing required argument: <r1>", fn ->
      exec(spec, [])
    end
    assert_raise RuntimeError, "Missing required argument: <r2>", fn ->
      exec(spec, ["a"])
    end
    assert parse(spec, ["a", "b"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{
        "r1" => "a", "r2" => "b"
      }, subcmd: nil
    }}
    assert parse(spec, ["a", "b", "c"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{
        "o1" => "a", "r1" => "b", "r2" => "c"
      }, subcmd: nil
    }}
    assert parse(spec, ["a", "b", "c", "d"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{
        "o1" => "a", "o2" => "b", "r1" => "c", "r2" => "d"
      }, subcmd: nil
    }}
    assert parse(spec, ["a", "b", "c", "d", "e"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{
        "o1" => "a", "o2" => "b", "r1" => "c", "r2" => "d", "r3" => ["e"]
      }, subcmd: nil
    }}
    assert parse(spec, ["a", "b", "c", "d", "e", "f"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{
        "o1" => "a", "o2" => "b", "r1" => "c", "r2" => "d", "r3" => ["e", "f"]
      }, subcmd: nil
    }}
  end

  test "just options" do
    spec = [name: "tool", options: [[name: :hi]]]
    assert parse(spec, []) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--hi=hello"]) == {:ok, %Cmd{
      name: "tool", options: [hi: "hello"], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--hi", "hello"]) == {:ok, %Cmd{
      name: "tool", options: [hi: "hello"], arguments: %{}, subcmd: nil
    }}
    assert_raise RuntimeError, "Missing argument for option: --hi", fn ->
      exec(spec, ["--hi"])
    end
    assert_raise RuntimeError, "Unrecognized option: -o", fn ->
      exec(spec, ["-o"])
    end
    assert_raise RuntimeError, "Unrecognized option: --bye", fn ->
      exec(spec, ["--bye"])
    end
    assert_raise RuntimeError, "Unrecognized option: --bye", fn ->
      exec(spec, ["--bye", "hello"])
    end
    assert_raise RuntimeError, "Unrecognized option: ---bye", fn ->
      exec(spec, ["---bye"])
    end

    spec = [name: "tool", options: [[name: :hi, required: true]]]
    assert_raise RuntimeError, "Missing required option: --hi", fn ->
      exec(spec, [])
    end
    assert_raise RuntimeError, "Missing required option: --hi", fn ->
      exec(spec, ["hello"])
    end
    assert_raise RuntimeError, "Missing argument for option: --hi", fn ->
      exec(spec, ["--hi"])
    end
    assert parse(spec, ["--hi=hello"]) == {:ok, %Cmd{
      name: "tool", options: [hi: "hello"], arguments: %{}, subcmd: nil
    }}

    spec = [name: "tool", options: [[name: :hi, argtype: :integer]]]
    assert_raise RuntimeError, "Missing argument for option: --hi", fn ->
      exec(spec, ["--hi"])
    end
    assert_raise RuntimeError, "Bad option value for --hi: hello", fn ->
      exec(spec, ["--hi=hello"])
    end
    assert parse(spec, ["--hi", "13"]) == {:ok, %Cmd{
      name: "tool", options: [hi: 13], arguments: %{}, subcmd: nil
    }}

    spec = [name: "tool", options: [[name: :hi, argtype: :boolean]]]
    assert_raise RuntimeError, "Bad option value for --hi: hello", fn ->
      exec(spec, ["--hi=hello"])
    end
    assert parse(spec, ["--hi"]) == {:ok, %Cmd{
      name: "tool", options: [hi: true], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--no-hi"]) == {:ok, %Cmd{
      name: "tool", options: [hi: false], arguments: %{}, subcmd: nil
    }}
  end

  test "combined option name" do
    spec = [name: "tool", options: [
      [name: [:long_name, :l], argtype: :boolean],
      [name: [:s, :short], argtype: :boolean],
    ]]
    assert parse(spec, []) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["-l"]) == {:ok, %Cmd{
      name: "tool", options: [long_name: true], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--long-name"]) == {:ok, %Cmd{
      name: "tool", options: [long_name: true], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--no-long-name"]) == {:ok, %Cmd{
      name: "tool", options: [long_name: false], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["-s"]) == {:ok, %Cmd{
      name: "tool", options: [short: true], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--short"]) == {:ok, %Cmd{
      name: "tool", options: [short: true], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--no-short"]) == {:ok, %Cmd{
      name: "tool", options: [short: false], arguments: %{}, subcmd: nil
    }}
  end

  test "defaults for options" do
    spec = [name: "tool", arguments: [[required: false]], options: [
      [name: :host, short: :h, default: "localhost"],
      [name: :port, short: :p, argtype: :integer, default: 1234],
    ]]

    assert parse(spec, []) == {:ok, %Cmd{
      name: "tool", options: [host: "localhost", port: 1234], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--port=12"]) == {:ok, %Cmd{
      name: "tool", options: [port: 12, host: "localhost"], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["-h", "..."]) == {:ok, %Cmd{
      name: "tool", options: [host: "...", port: 1234], arguments: %{}, subcmd: nil
    }}
  end

  test "defaults for arguments" do
    spec = [name: "tool", arguments: [
      [name: "path", required: false, default: "."],
      [name: "port"],
    ]]

    assert parse(spec, ["12"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{
        "path" => ".", "port" => "12"
      }, subcmd: nil
    }}
    assert parse(spec, ["home/", "33"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{
        "path" => "home/", "port" => "33"
      }, subcmd: nil
    }}
  end

  test ":overwrite modifier for options" do
    spec = [name: "tool", arguments: [[required: false]], options: [
      [name: :mercury, argtype: :boolean, multival: :overwrite],
    ]]

    assert parse(spec, ["--mercury"]) == {:ok, %Cmd{
      name: "tool", options: [mercury: true], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--mercury", "--mercury=false"]) == {:ok, %Cmd{
      name: "tool", options: [mercury: false], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--no-mercury", "--mercury"]) == {:ok, %Cmd{
      name: "tool", options: [mercury: true], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--no-mercury", "--mercury", "foo"]) == {:ok, %Cmd{
      name: "tool", options: [mercury: true], arguments: %{"arg" => "foo"}, subcmd: nil
    }}
  end

  test ":keep modifier for options" do
    spec = [name: "tool", arguments: [[required: false]], options: [
      [name: :mercury, argtype: :boolean, multival: :overwrite],
      [name: :venus, argtype: :integer, multival: :keep],
    ]]

    assert parse(spec, ["--venus=13"]) === {:ok, %Cmd{
      name: "tool", options: [venus: 13], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--venus", "13", "--venus=0"]) === {:ok, %Cmd{
      name: "tool", options: [venus: 13, venus: 0], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--venus=13", "--mercury", "--venus", "4"]) === {:ok, %Cmd{
      name: "tool", options: [venus: 13, mercury: true, venus: 4], arguments: %{}, subcmd: nil
    }}
  end

  test ":accumulate modifier for options" do
    spec = [name: "tool", arguments: [[required: false]], options: [
      [name: :venus, argtype: :integer, multival: :keep],
      [name: :earth, argtype: :float, multival: :accumulate],
    ]]

    assert parse(spec, ["--earth=13"]) === {:ok, %Cmd{
      name: "tool", options: [earth: [13.0]], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--earth", "13", "--earth=0"]) === {:ok, %Cmd{
      name: "tool", options: [earth: [13.0, 0.0]], arguments: %{}, subcmd: nil
    }}
    assert parse(spec, ["--earth=13", "--venus", "11", "--earth", "4"]) === {:ok, %Cmd{
      name: "tool", options: [earth: [13.0, 4.0], venus: 11], arguments: %{}, subcmd: nil
    }}
  end

  test ":error modifier for options" do
    spec = [name: "tool", arguments: [[required: false]], options: [
      [name: :earth, argtype: :float, multival: :accumulate],
      [name: :mars, argtype: :string, multival: :error],
    ]]

    assert parse(spec, ["--mars=13"]) == {:ok, %Cmd{
      name: "tool", options: [mars: "13"], arguments: %{}, subcmd: nil
    }}
    msg = "Error trying to overwrite the value for option --mars"
    assert_raise RuntimeError, msg, fn ->
      exec(spec, ["--mars", "hi", "--mars=bye"])
    end
    assert_raise RuntimeError, msg, fn ->
      exec(spec, ["--mars=hi", "--earth=1", "--mars", "bye"])
    end
  end


  test "options and arguments" do
    spec = [name: "tool", arguments: [
      [name: "path"],
      [name: "port", required: false]
    ], options: [
      [name: :earth, argtype: :float],
      [name: :mars, argtype: :string],
      [short: :o, argtype: :string, required: true],
    ]]

    assert_raise RuntimeError, "Missing required argument: <path>", fn ->
      exec(spec, ["-o", "1"])
    end
    assert_raise RuntimeError, "Missing required option: -o", fn ->
      exec(spec, ["foo"])
    end
    assert parse(spec, ["-o", "home", "path", "port"]) == {:ok, %Cmd{
      name: "tool", options: [o: "home"], arguments: %{"path" => "path", "port" => "port"}, subcmd: nil
    }}
    assert parse(spec, ["-o", ".", "home", "--earth=13"]) == {:ok, %Cmd{
      name: "tool", options: [o: ".", earth: 13.0], arguments: %{"path" => "home"}, subcmd: nil
    }}
  end


  test "option target" do
    spec = [name: "tool", options: [
      [name: :planets, multival: :accumulate, hidden: true],

      [name: :earth, store: :self, target: :planets],
      [name: :mars, store: :self, target: :planets],
    ], arguments: [
      [name: "planet", nargs: :inf, argtype: {:choice, ["venus", "pluto"]}],
    ]]

    assert parse(spec, ["--earth", "venus", "--mars", "pluto"]) == {:ok, %Cmd{
      name: "tool", options: [planets: ["earth", "mars"]], arguments: %{
        "planet" => ["venus", "pluto"]
      }
    }}
  end


  test ":const argtype" do
    spec = [name: "tool", options: [
      [name: :planet, multival: :accumulate, hidden: true],

      [name: :earth, store: {:const, 3}, target: :planet],
      [name: :mars, store: {:const, 4}, target: :planet],

      [name: :switch, store: {:const, :atom}],
    ]]

    assert parse(spec, ["--earth", "--mars", "--earth"]) == {:ok, %Cmd{
      name: "tool", options: [planet: [3, 4, 3]], arguments: %{}
    }}
    assert parse(spec, ["--switch", "--mars", "--earth"]) == {:ok, %Cmd{
      name: "tool", options: [switch: :atom, planet: [4, 3]], arguments: %{}
    }}
  end


  test ":self argtype" do
    spec = [name: "tool", options: [
      [name: :planet, multival: :accumulate, hidden: true],

      [name: :earth, store: :self, target: :planet],
      [name: :mars, store: :self, target: :planet],
    ]]

    assert parse(spec, ["--earth", "--mars", "--earth"]) == {:ok, %Cmd{
      name: "tool", options: [planet: ["earth", "mars", "earth"]], arguments: %{}
    }}
  end


  test ":choice argtype" do
    spec = [name: "tool", arguments: [
      [name: "target", argtype: {:choice, ["i386", "x86_64", "armv7"]}],
    ], options: [
      [name: :planet, argtype: {:choice, :integer, [2, 4, 9]}, multival: :accumulate],
    ]]

    assert parse(spec, ["i386", "--planet", "2", "--planet=9"]) == {:ok, %Cmd{
      name: "tool", options: [planet: [2, 9]], arguments: %{"target" => "i386"}
    }}

    msg = "Bad argument value for <target>: 386. Has to be one of: i386, x86_64, armv7"
    assert_raise RuntimeError, msg, fn ->
      exec(spec, ["386"])
    end
    msg = "Bad option value for --planet: Pluto"
    assert_raise RuntimeError, msg, fn ->
      exec(spec, ["--planet", "Pluto", "armv7"])
    end
    msg = "Bad option value for --planet: 3. Has to be one of: 2, 4, 9"
    assert_raise RuntimeError, msg, fn ->
      exec(spec, ["--planet", "3", "armv7"])
    end
  end

  test "optional option value" do
    spec = [name: "tool", options: [
      [name: :exec_path, argtype: [:string, :optional]],
    ]]

    assert parse(spec, []) == {:ok, %Cmd{
      name: "tool", options: [], arguments: %{}
    }}
    assert_raise RuntimeError, "Unrecognized option: --exec_path", fn ->
      exec(spec, ["--exec_path"])
    end
    assert parse(spec, ["--exec-path"]) == {:ok, %Cmd{
      name: "tool", options: [exec_path: nil], arguments: %{}
    }}
    assert_raise RuntimeError, "Unexpected argument: a", fn ->
      exec(spec, ["--exec-path", "a"])
    end
    assert parse(spec, ["--exec-path=a"]) == {:ok, %Cmd{
      name: "tool", options: [exec_path: "a"], arguments: %{}
    }}
  end

  test "actions" do
    opt_action = fn
      {_name, nil}, _spec ->
        IO.write "Current path is: ..."
        :halt

      opt, _spec -> opt
    end

    arg_action = fn
      {name, val}=arg, _spec ->
        IO.write "Got value #{val} for arg #{name}"
        arg
    end

    spec = [name: "tool", options: [
      [name: :path, argtype: [:string, :optional], action: opt_action],
    ], arguments: [
      [name: "word", nargs: :inf, required: false, action: arg_action],
    ]]

    import ExUnit.CaptureIO

    assert capture_io(fn ->
      assert catch_exit(exec(spec, ["--path"], halt: :exit)) == {Commando, 0}
    end) == "Current path is: ..."

    assert capture_io(fn ->
      assert catch_exit(exec(spec, ["--path", "a"], halt: :exit)) == {Commando, 0}
    end) == "Current path is: ..."

    assert parse(spec, ["--path=a"]) == {:ok, %Cmd{
      name: "tool", options: [path: "a"], arguments: %{}
    }}

    assert capture_io(fn ->
      assert parse(spec, ["--path=a", "b"]) == {:ok, %Cmd{
        name: "tool", options: [path: "a"], arguments: %{"word" => ["b"]}
      }}
    end) == "Got value b for arg word"
  end

  test "subcommands" do
    spec = [
      name: "tool",
      options: [[name: :log, argtype: :boolean], [short: :v]],
      commands: [
        [name: "cmda", options: [[name: :opt_a], [name: :opt_b, required: true]]],
        [name: "cmdb", options: [[short: :v], [short: :p]], arguments: [[]]],
      ],
    ]

    assert_raise RuntimeError, "Missing command", fn ->
      exec(spec, [])
    end
    assert_raise RuntimeError, "Unrecognized command: hello", fn ->
      exec(spec, ["--log", "-v", ".", "hello"])
    end
    assert_raise RuntimeError, "Missing required option: --opt-b", fn ->
      exec(spec, ["--log", "-v", ".", "cmda"])
    end

    assert parse(spec, ["--log", "-v", ".", "cmda", "--opt-b=0"]) == {:ok, %Cmd{
      name: "tool", options: [log: true, v: "."], arguments: nil, subcmd: %Cmd{
        name: "cmda", options: [opt_b: "0"], arguments: %{}, subcmd: nil
      }
    }}

    assert_raise RuntimeError, "Unrecognized option: --opt-b", fn ->
      exec(spec, ["cmdb", "--opt-b=0"])
    end

    assert_raise RuntimeError, "Missing required argument: <arg>", fn ->
      exec(spec, ["cmdb"])
    end

    assert parse(spec, ["cmdb", "hello"]) == {:ok, %Cmd{
      name: "tool", options: [], arguments: nil, subcmd: %Cmd{
        name: "cmdb", options: [], arguments: %{"arg" => "hello"}, subcmd: nil
      }
    }}

    assert parse(spec, ["-v", "0", "cmdb", "-v", "1", "hello", "-p", "2"]) == {:ok, %Cmd{
      name: "tool", options: [v: "0"], arguments: nil, subcmd: %Cmd{
        name: "cmdb", options: [v: "1", p: "2"], arguments: %{"arg" => "hello"}, subcmd: nil
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

    assert parse(spec, ["help"]) == {:ok, %Cmd {
      name: "tool", options: [], arguments: nil, subcmd: %Cmd {
        name: "help", options: [], arguments: %{}, subcmd: nil
      }
    }}

    assert parse(spec, ["help", "bad"]) == {:ok, %Cmd {
      name: "tool", options: [], arguments: nil, subcmd: %Cmd {
        name: "help", options: [], arguments: %{"command" => "bad"}, subcmd: nil
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
        command   The command to describe. When omitted, help for the program itself is printed.

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


  defp parse(spec, args) do
    spec = Commando.new(spec)
    Commando.parse(args, spec)
  end

  defp exec(spec, args, config \\ [on_error: :raise]) do
    spec = Commando.new(spec)
    Commando.exec(args, spec, config)
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
