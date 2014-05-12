defmodule CommandoTest.ErrorsTest do
  use ExUnit.Case

  test "missing fields" do
    msg = "Missing :name option for the command"
    assert_raise ArgumentError, msg, fn ->
      Commando.new []
    end
  end

  test "mixing arguments and commands" do
    msg = "Options :commands and :arguments are incompatible with each other"
    assert_raise ArgumentError, msg, fn ->
      Commando.new name: "tool", arguments: [], commands: []
    end
  end

  test "required and optional arguments" do
    msg = "Required arguments cannot follow optional ones"
    assert_raise ArgumentError, msg, fn ->
      Commando.new name: "tool", arguments: [
        [optional: true],
        [],
      ]
    end
  end
end
