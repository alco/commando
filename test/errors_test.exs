defmodule CommandoTest.ErrorsTest do
  use ExUnit.Case

  test "missing fields" do
    msg = "Missing :name option for the command"
    assert_raise ArgumentError, msg, fn ->
      Commando.new([])
    end
  end

  test "mixing arguments and commands" do
    msg = "Options :commands and :arguments are mutually exclusive"
    assert_raise ArgumentError, msg, fn ->
      Commando.new(name: "tool", arguments: [], commands: [])
    end
  end

  test "required and optional arguments" do
    msg = "Duplicate argument name: arg"
    assert_raise ArgumentError, msg, fn ->
      Commando.new(name: "tool", arguments: [
        [required: false],
        [],
      ])
    end
  end
end
