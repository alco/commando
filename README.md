Commando
========

Create consistent and powerful command-line interfaces (CLIs) for your Elixir
programs.

Commando gives you a declarative way to define the CLI. It provides advanced
argument parsing functionality on top of `OptionParser`, automates some of the
tasks like printing the help and usage of the program, and lets you build a
hierarchy of commands (like in `git`, for instance) with actions attached to
them.


## Rationale

What problems is Commando aiming to solve?

  * Concise, declarative definition of a command-line interface containing
    enough information to automate most commonly encountered parsing tasks,
    such as:

    - defining options, arguments, and commands
    - specifying types and arguments for options, option groups, option actions
    - supporting a hierarchy of commands

  * Formatting the help and usage messages for the console. There should be an
    ability to automatically generate the full output and allow the user to
    hand-craft parts (or all) of it.

  * Giving the user full control over the parsed result. Commando can either
    take over the program execution by relying on the supplied actions or
    return a data structure representation of the program invocation to let the
    user post-process it further.


## Basic usage

A simple example of creating a command-line utility with Commando:

```elixir
spec = [
  name: "mycat",
  version: "0.1",

  # print only short options in the "usage" line
  list_options: :short,

  # options start with - or -- and are can be omitted by default
  options: [
    # builtin [-h|--help] option
    :help,

    # alias for [-V|--version] option
    {:version, :V},

    [name: :config, argname: "path", help: "Path to the config file"],
    [name: [:verbose, :v], argtype: :boolean, help: "Print debug information"],
  ],

  # arguments are required by default
  arguments: [
    [name: "path", help: "Path to the file to print"],
  ],
]

cmd = Commando.new(spec)
Commando.exec(cmd)
```

Save the above code to a file and run it with `mix run <filename>`. For
example:

```
$ mix run mycat.exs --version
0.1

$ mix run mycat.exs -v
Missing required argument: <path>

$ mix run mycat.exs -h
Usage:
  mycat [-h] [-V] [-v] <path>

Arguments:
  path      Path to the file to print

Options:
  -h, --help
    Print description of the command.

  -V, --version
    Print version information and exit.

  --config=<path>
    Path to the config file

  -v, --verbose
    Print debug information

```

Calling `exec()` takes over the execution of your program. It will generate a
help message, will handle the `--version` and `--help` options automatically,
execute any actions attached to user-defined options and arguments, and will
also handles parsing errors. It is possible to customize the default behaviour.

Alternatively, you can use the `parse()` function to get a `Commando.Cmd`
struct containing the parsed invocation:

```elixir
cmd = Commando.new(spec)
Commando.parse(["-v", "/"], cmd)
# result:
{:ok, %Commando.Cmd{
  name: "mycat",
  options: [verbose: true],
  arguments: %{"path" => "/"},
  subcmd: nil
}}
```

The `subcmd` field contains the parsed command if one is defined. It will be
described in a separate section below.

Some of the available features of Commando are demonstrated in the programs
inside the `example/` directory.

Below is a brief survey of the commonly used features.


### Options

An option is defined as a keyword list of parameters under the `:options` key
in the command specification. Some of the more common ones are

* `name`, `short` – long and short names of the option

* `argtype` – type of the value the option takes. Possible types are:
  `:string`, `:integer`, `:boolean`, `{:choice, <list of values>}`, etc.
  Default type is `:string`

* `required` – whether the option has to be present. Default is `false`

* `help` – description of the option that will be printed by `--help`
  or the `help` command

Two predefined options are available:

* `help_option: :top_cmd` – defined at the top level of the command
  specification; adds an `-h|--help` option that prints the command's help and
  exits

* `:version` or `{:version, :v|:V}` – adds a `-v|--version` (or `-V|--version`)
  option that prints the command's version and exits


### Arguments

An arguments is also defined as a keyword list of parameters, under the
`:arguments` key in the command specification. It shares some of the option
parameters, namely `name`, `argtype`, `required`, `help`. In addition to that,
it has

* `nargs` – currently, the only possible value is `:inf`; turns the argument
  into a "glob" that consumes all the remaining arguments passed to the
  command.

  When combined with the `required` parameter, allows us to specify whether at
  least one argument has to be present or all of them are optional.


### Commands

Commands can be defined instead of arguments, the two are mutually exclusive.


## Formatters

The help messages are generated by the default formatter. Commando supports
using a custom formatter.


## Other ways of defining the CLI

  * Schemata is a validation layer that can be used as part of Commando CLI
    definition

  * CommandoDSL is a lightweight wrapper on top of Commando that provides a DSL
    for defining the CLI.

  * Commandoc takes on an approach that is similar to docopt.

---

TODO:

* customizable help and usage formatting options
* execute --version and --help actions as soon as they are encountered
* allow passing the help string through a filter (like Mix.shell.info)
* callback-based API for the help messages

* REFACTOR ALL THE THINGS!!!
