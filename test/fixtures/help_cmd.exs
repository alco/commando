defmodule HelpCommand do
  def run do
    spec = [
      name: "tool",
      help: "A very practical tool.",
      list_options: :all,
      options: [
        [short: :v, name: :verbose, argtype: :boolean],
        [short: :d, argtype: :boolean],
      ],
      commands: [
        :help,
        [name: "cmd", options: [
          [name: :opt, required: true],
          [name: :foo, short: :f, argtype: :boolean],
        ], arguments: [
          [required: false],
        ]],
      ],
    ]
    Commando.new(spec) |> Commando.parse()
  end
end

HelpCommand.run
