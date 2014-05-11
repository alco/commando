defmodule CommandoTest.ErrorsTest do
  use ExUnit.Case

  test "missing fields" do
    assert_raise ArgumentError, "Missing :name option for the command", fn ->
      Commando.new []
    end
  end
end
