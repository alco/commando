defmodule CommandoTest.ErrorsTest do
  use ExUnit.Case

  test "missing fields" do
    msg = "Missing :name option for the command"
    assert Commando.new([]) == {:error, msg}
  end

  test "mixing arguments and commands" do
    msg = "Options :commands and :arguments are mutually exclusive"
    assert Commando.new(name: "tool", arguments: [], commands: [])
           == {:error, msg}
  end

  test "required and optional arguments" do
    msg = "Required arguments cannot follow optional ones"
    assert Commando.new(name: "tool", arguments: [
      [optional: true],
      [],
    ]) == {:error, msg}
  end
end
