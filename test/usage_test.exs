defmodule CommandoTest.UsageTest do
  use ExUnit.Case

  test "basic command" do
    assert tool_usage([]) == "tool"
  end

  test "just arguments" do
    assert tool_usage([[]]) == "tool <arg>"
    assert tool_usage([[name: "path"]]) == "tool <path>"
    assert tool_usage([[name: "path", optional: true]]) == "tool [path]"
    assert tool_usage([[name: "path"], [name: "port", optional: true]])
           == "tool <path> [port]"
  end


  defp tool_usage(args) do
    cmd = Commando.new [name: "tool", arguments: args]
    Commando.usage(cmd) |> String.strip
  end
end
