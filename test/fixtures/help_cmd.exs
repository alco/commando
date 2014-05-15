defmodule HelpCommand do
  def run do
    spec = [
      name: "tool",
      help: "A very practical tool.",
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
    {:ok, cmd} = Commando.new(spec)
    Commando.parse(cmd, config: [autoexec: :help])
  end
end

HelpCommand.run
