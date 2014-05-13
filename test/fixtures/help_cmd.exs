defmodule HelpCommand do
  def run do
    spec = [
      name: "tool",
      help: "A very practical tool.",
      exec_help: true,
      list_options: :all,
      options: [
        [short: "v", name: "verbose", valtype: :boolean],
        [short: "d", valtype: :boolean],
      ],
      commands: [
        :help,
        [name: "cmd", options: [
          [name: "opt", required: true],
          [name: "foo", short: "f", valtype: :boolean],
        ], arguments: [
          [optional: true],
        ]],
      ],
    ]
    cmd = Commando.new(spec)
    IO.inspect Commando.parse(cmd)
  end
end

HelpCommand.run
