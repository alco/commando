defmodule CommandoTest.ParseTest do
  use ExUnit.Case

  alias Commando.Cmd

  test "basic command" do
    assert parse([name: "tool"], []) == %Cmd{
      options: [], arguments: [], subcmd: nil
    }
  end

  test "just arguments" do
    spec = [name: "tool", arguments: []]
    assert parse(spec, []) == %Cmd{
      options: [], arguments: [], subcmd: nil
    }

    spec = [name: "tool", arguments: []]
    assert_raise RuntimeError, "Unexpected argument: hello", fn ->
      parse(spec, ["hello"])
    end

    spec = [name: "tool", arguments: [[name: "path", optional: true]]]
    assert parse(spec, []) == %Cmd{
      options: [], arguments: [], subcmd: nil
    }
    assert parse(spec, ["hi"]) == %Cmd{
      options: [], arguments: ["hi"], subcmd: nil
    }

    spec = [name: "tool", arguments: [[name: "path"]]]
    assert_raise RuntimeError, "Missing required argument: <path>", fn ->
      parse(spec, [])
    end
    assert parse(spec, ["hi"]) == %Cmd{
      options: [], arguments: ["hi"], subcmd: nil
    }
    assert_raise RuntimeError, "Unexpected argument: world", fn ->
      parse(spec, ["hello", "world"])
    end

    spec = [name: "tool", arguments: [[name: "path"], [name: "port", optional: true]]]
    assert_raise RuntimeError, "Missing required argument: <path>", fn ->
      parse(spec, [])
    end
    assert parse(spec, ["home"]) == %Cmd{
      options: [], arguments: ["home"], subcmd: nil
    }
    assert parse(spec, ["home", "extra"]) == %Cmd{
      options: [], arguments: ["home", "extra"], subcmd: nil
    }
    assert_raise RuntimeError, "Unexpected argument: more", fn ->
      parse(spec, ["home", "extra", "more"])
    end
  end

  test "just options" do
    spec = [name: "tool", options: [[name: "hi"]]]
    assert parse(spec, []) == %Cmd{
      options: [], arguments: [], subcmd: nil
    }
    assert parse(spec, ["--hi=hello"]) == %Cmd{
      options: [hi: "hello"], arguments: [], subcmd: nil
    }
    assert parse(spec, ["--hi", "hello"]) == %Cmd{
      options: [hi: "hello"], arguments: [], subcmd: nil
    }
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
    assert parse(spec, ["--hi=hello"]) == %Cmd{
      options: [hi: "hello"], arguments: [], subcmd: nil
    }

    spec = [name: "tool", options: [[name: "hi", valtype: :integer]]]
    assert_raise RuntimeError, "Missing argument for option: --hi", fn ->
      parse(spec, ["--hi"])
    end
    assert_raise RuntimeError, "Bad option value for --hi: hello", fn ->
      parse(spec, ["--hi=hello"])
    end
    assert parse(spec, ["--hi", "13"]) == %Cmd{
      options: [hi: 13], arguments: [], subcmd: nil
    }

    spec = [name: "tool", options: [[name: "hi", valtype: :boolean]]]
    assert_raise RuntimeError, "Bad option value for --hi: hello", fn ->
      parse(spec, ["--hi=hello"])
    end
    assert parse(spec, ["--hi"]) == %Cmd{
      options: [hi: true], arguments: [], subcmd: nil
    }
    assert parse(spec, ["--no-hi"]) == %Cmd{
      options: [hi: false], arguments: [], subcmd: nil
    }
  end

  test ":overwrite modifier for options" do
    spec = [name: "tool", arguments: [[optional: true]], options: [
      [name: "mercury", valtype: :boolean, multival: :overwrite],
    ]]

    assert parse(spec, ["--mercury"]) == %Cmd{
      options: [mercury: true], arguments: [], subcmd: nil
    }
    assert parse(spec, ["--mercury", "--mercury=false"]) == %Cmd{
      options: [mercury: false], arguments: [], subcmd: nil
    }
    assert parse(spec, ["--no-mercury", "--mercury"]) == %Cmd{
      options: [mercury: true], arguments: [], subcmd: nil
    }
    assert parse(spec, ["--no-mercury", "--mercury", "foo"]) == %Cmd{
      options: [mercury: true], arguments: ["foo"], subcmd: nil
    }
  end

  test ":keep modifier for options" do
    spec = [name: "tool", arguments: [[optional: true]], options: [
      [name: "mercury", valtype: :boolean, multival: :overwrite],
      [name: "venus", valtype: :integer, multival: :keep],
    ]]

    assert parse(spec, ["--venus=13"]) === %Cmd{
      options: [venus: 13], arguments: [], subcmd: nil
    }
    assert parse(spec, ["--venus", "13", "--venus=0"]) === %Cmd{
      options: [venus: 13, venus: 0], arguments: [], subcmd: nil
    }
    assert parse(spec, ["--venus=13", "--mercury", "--venus", "4"]) === %Cmd{
      options: [venus: 13, mercury: true, venus: 4], arguments: [], subcmd: nil
    }
  end

  test ":accumulate modifier for options" do
    spec = [name: "tool", arguments: [[optional: true]], options: [
      [name: "venus", valtype: :integer, multival: :keep],
      [name: "earth", valtype: :float, multival: :accumulate],
    ]]

    assert parse(spec, ["--earth=13"]) === %Cmd{
      options: [earth: [13.0]], arguments: [], subcmd: nil
    }
    assert parse(spec, ["--earth", "13", "--earth=0"]) === %Cmd{
      options: [earth: [13.0, 0.0]], arguments: [], subcmd: nil
    }
    assert parse(spec, ["--earth=13", "--venus", "11", "--earth", "4"]) === %Cmd{
      options: [earth: [13.0, 4.0], venus: 11], arguments: [], subcmd: nil
    }
  end

  test ":error modifier for options" do
    spec = [name: "tool", arguments: [[optional: true]], options: [
      [name: "earth", valtype: :float, multival: :accumulate],
      [name: "mars", valtype: :string, multival: :error],
    ]]

    assert parse(spec, ["--mars=13"]) == %Cmd{
      options: [mars: "13"], arguments: [], subcmd: nil
    }
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
      [name: "port", optional: true]
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
    assert parse(spec, ["-o", "home", "path", "port"]) == %Cmd{
      options: [o: "home"], arguments: ["path", "port"], subcmd: nil
    }
    assert parse(spec, ["-o", ".", "home", "--earth=13"]) == %Cmd{
      options: [o: ".", earth: 13.0], arguments: ["home"], subcmd: nil
    }
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

    assert parse(spec, ["--log", "-v", ".", "cmda", "--opt-b=0"]) == %Cmd{
      options: [log: true, v: "."], arguments: [], subcmd: %Cmd{
        options: [opt_b: "0"], arguments: [], subcmd: nil
      }
    }

    assert_raise RuntimeError, "Unrecognized option: --opt-b", fn ->
      parse(spec, ["cmdb", "--opt-b=0"])
    end

    assert_raise RuntimeError, "Missing required argument: <arg>", fn ->
      parse(spec, ["cmdb"])
    end

    assert parse(spec, ["cmdb", "hello"]) == %Cmd{
      options: [], arguments: [], subcmd: %Cmd{
        options: [], arguments: ["hello"], subcmd: nil
      }
    }

    assert parse(spec, ["-v", "0", "cmdb", "-v", "1", "hello", "-p", "2"]) == %Cmd{
      options: [v: "0"], arguments: [], subcmd: %Cmd{
        options: [v: "1", p: "2"], arguments: ["hello"], subcmd: nil
      }
    }
  end

  #test "autohelp subcommand" do
    #spec = [
      #name: "tool",
      #options: [[name: "log", valtype: :boolean], [short: "v"]],
      #commands: [
        #:help,
        #[name: "cmda", options: [[name: "opt_a"], [name: "opt_b", required: true]]],
        #[name: "cmdb", options: [[short: "o"], [short: "p"]], arguments: [[]]],
      #],
    #]

    #assert usage(spec, "help") == "tool help [<command>]"
  #end


  defp parse(spec, args),
    do: Commando.new(spec) |> Commando.parse(args)
end
