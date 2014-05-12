defmodule Commando.Cmd do
  defstruct [
    options: [],
    arguments: [],
    subcmd: nil,
  ]
end

defmodule Commando do
  @spec_defaults %{
    width: 40,
    prefix: "",
    options: [],
  }

  @opt_defaults %{
    valtype: :string,
    required: false,
    help: "",
  }

  @cmd_arg_defaults %{
    optional: false,
    help: "",
  }


  @doc """
  Create a new command specification.
  """
  def new(spec) do
    process_definition(spec, @spec_defaults) |> validate_spec()
  end

  @doc """
  Parse command-line arguments according to the spec.
  """
  def parse(spec, args \\ System.argv) do
    {switches, aliases} = spec_to_parser_opts(spec)
    opts = [switches: switches, aliases: aliases]
    {opts, args} = case OptionParser.parse_head(args, opts) do
      {_, _, invalid} when invalid != [] ->
        raise RuntimeError, message: "Bad options: #{inspect invalid}"

      {opts, ["--"|args], []} -> {opts, args}
      {opts, args, []}        -> {opts, args}
    end
    postprocess_opts_and_args(spec, opts, args)
  end

  @doc """
  Print usage for the spec or one of its subcommands.
  """
  def usage(spec, cmd \\ nil)

  def usage(spec, nil) do
    option_text = format_options(spec[:options], spec[:list_options])
    arg_text = cond do
      spec[:commands] -> "<command> [...]"
      arguments=spec[:arguments] -> format_arguments(arguments)
      true -> ""
    end

    [spec[:prefix], spec[:name], option_text, arg_text]
    |> Enum.reject(&( &1 == "" ))
    |> Enum.join(" ")
  end

  def usage(spec, cmd) when is_binary(cmd) do
    unless cmd_spec = Enum.find(spec[:commands], &( &1[:name] == cmd )) do
      raise ArgumentError, "Undefined command #{cmd}"
    end
    Map.merge(cmd_spec, %{
      prefix: Enum.join([spec[:prefix], spec[:name]], " "),
      list_options: spec[:list_options],
    })
    |> usage()
  end

  @doc """
  Print help for the spec or one of its subcommands.
  """
  def help(spec, cmd \\ nil)

  def help(%{help: {:full, help}}=spec, nil) do
    help
    |> String.replace("{{usage}}", usage(spec))
    |> String.replace("{{options}}", format_option_list(spec[:options]))
    |> String.replace("{{commands}}", format_command_list(spec[:commands]))
    |> String.replace("{{arguments}}", format_argument_list(spec[:arguments]))
  end

  def help(%{help: help}=spec, nil) do
    options = spec[:options]
    option_text = if not (options in [nil, []]) do
      "Options:\n" <> format_option_list(options)
    end

    cmd_arg_text = cond do
      commands=spec[:commands] ->
        "Commands:\n" <> format_command_list(commands)

      arguments=spec[:arguments] ->
        "Arguments:\n" <> format_argument_list(arguments)

      true -> ""
    end

    lines =
      [help, option_text, cmd_arg_text]
      |> Enum.reject(&( &1 in [nil, ""] ))
      |> Enum.join("\n\n")
    if lines != "", do: lines = "\n" <> lines

    """
    Usage:
      #{usage(spec)}
    #{lines}
    """
  end

  def help(%{}=spec, cmd) do
    unless cmd_spec = Enum.find(spec[:commands], &( &1[:name] == cmd )) do
      raise ArgumentError, "Undefined command #{cmd}"
    end
    Map.merge(cmd_spec, %{
      prefix: Enum.join([spec[:prefix], spec[:name]], " "),
      list_options: spec[:list_options],
    })
    |> help()
  end

  ###

  defp format_option_list(null) when null in [nil, []], do: ""

  defp format_option_list(options),
    do: (Enum.map(options, &format_option_help/1) |> Enum.join("\n\n"))


  defp format_command_list(null) when null in [nil, []], do: ""

  defp format_command_list(commands),
    do: (Enum.map(commands, &format_command_brief/1) |> Enum.join("\n"))


  defp format_argument_list(null) when null in [nil, []], do: ""

  defp format_argument_list(arguments),
    do: (Enum.map(arguments, &format_argument_help/1) |> Enum.join("\n"))


  defp format_options(null, _) when null in [nil, []], do: ""

  defp format_options(_, nil), do: "[options]"

  defp format_options(options, list_kind),
    do: (Enum.map(options, &(format_option(&1, list_kind) |> wrap_option(&1, list_kind))) |> Enum.join(" "))


  defp format_option(opt, :short) do
    if name=opt[:short] do
      name = "-#{name_to_opt(name)}"
      if argname=opt[:argname], do: name = "#{name} <#{argname}>"
      name
    end
  end

  defp format_option(opt, :long) do
    if name = opt[:name] do
      name = "--#{name_to_opt(name)}"
      if argname=opt[:argname], do: name = "#{name}=<#{argname}>"
      name
    end
  end

  defp format_option(opt, :all) do
    [format_option(opt, :short), format_option(opt, :long)]
    |> Enum.reject(&( &1 in [nil, ""] ))
    |> Enum.join("|")
  end


  defp format_option_help(opt=%{help: help}) do
    opt_str =
      [format_option(opt, :short), format_option(opt, :long)]
      |> Enum.reject(&( &1 in [nil, ""] ))
      |> Enum.join(", ")
    if help == "", do: help = "(no documentation)"
    "  #{opt_str}\n    #{help}"
  end


  defp name_to_opt(name), do: String.replace(name, "_", "-")
  defp opt_to_name(opt), do: String.replace(opt, "-", "_")


  defp wrap_option(null, _, _) when null in [nil, ""], do: ""

  defp wrap_option(formatted, %{short: _, name: _, required: true}, :all),
    do: "{#{formatted}}"

  defp wrap_option(formatted, %{required: false}, _),
    do: "[#{formatted}]"

  defp wrap_option(formatted, _, _), do: formatted


  defp format_command_brief(cmd=%{name: name, help: ""}),
    do: "  #{:io_lib.format('~-10s', [name])}(no documentation)"

  defp format_command_brief(cmd=%{name: name, help: help}),
    do: "  #{:io_lib.format('~-10s', [name])}#{first_sentence(help)}"


  defp format_arguments([]), do: ""

  defp format_arguments(arguments),
    do: (Enum.map(arguments, &format_argument/1) |> Enum.join(" "))


  defp format_argument(%{name: name, optional: true}), do: "[<#{name}>]"
  defp format_argument(%{name: name}), do: "<#{name}>"


  defp format_argument_help(%{name: name, help: ""}),
    do: "  #{:io_lib.format('~-10s', [name])}(no documentation)"

  defp format_argument_help(%{name: name, help: help}),
    do: "  #{:io_lib.format('~-10s', [name])}#{help}"


  defp first_sentence(str) do
    case Regex.run(~r/\.(?:  ?[A-Z]|\n|$)/, str, [return: :index]) do
      [{pos, _}] -> elem(String.split_at(str, pos), 0)
      nil        -> str
    end
  end

  ###

  defp process_definition([], spec), do: spec

  defp process_definition([{:width, w}|rest], spec) when is_integer(w),
    do: process_definition(rest, %{spec | width: w})

  defp process_definition([{:name, n}|rest], spec) when is_binary(n),
    do: process_definition(rest, Map.put(spec, :name, n))

  defp process_definition([{:prefix, p}|rest], spec) when is_binary(p),
    do: process_definition(rest, %{spec | prefix: p})

  defp process_definition([{:usage, u}|rest], spec) when is_binary(u),
    do: process_definition(rest, Map.put(spec, :usage, u))

  defp process_definition([{:help, h}|rest], spec) when is_binary(h),
    do: process_definition(rest, Map.put(spec, :help, h))

  defp process_definition([{:help, {:full, h}=hh}|rest], spec) when is_binary(h),
    do: process_definition(rest, Map.put(spec, :help, hh))

  defp process_definition([{:options, opt}|rest], spec) when is_list(opt),
    do: process_definition(rest, %{spec | options: process_options(opt)})

  defp process_definition([{:list_options, kind}|rest], spec)
    when kind in [nil, :short, :long, :all],
    do: process_definition(rest, Map.put(spec, :list_options, kind))

  defp process_definition([{:arguments, arg}|rest], spec) when is_list(arg),
    do: process_definition(rest, Map.put(spec, :arguments, process_arguments(arg)))

  defp process_definition([{:commands, cmd}|rest], spec) when is_list(cmd),
    do: process_definition(rest, Map.put(spec, :commands, process_commands(cmd)))

  defp process_definition([opt|_], _) do
    raise ArgumentError, message: "Unrecognized option #{inspect opt}"
  end


  defp process_options(opt),
    do: Enum.map(opt, &(compile_option(&1) |> validate_option()))

  defp process_commands(cmd),
    do: Enum.map(cmd, &(compile_command(&1) |> validate_command()))

  defp process_arguments(arg),
    do: (Enum.map(arg, &(compile_argument(&1) |> validate_argument()))
         |> validate_arguments())


  defp compile_option(opt), do: compile_option(opt, @opt_defaults)

  defp compile_option([], opt), do: opt

  defp compile_option([{:name, <<_, _, _::binary>>=n}|rest], opt),
    do: compile_option(rest, Map.put(opt, :name, n))

  defp compile_option([{:short, <<_>>=s}|rest], opt),
    do: compile_option(rest, Map.put(opt, :short, s))

  defp compile_option([{:argname, n}|rest], opt) when is_binary(n),
    do: compile_option(rest, Map.put(opt, :argname, parse_argname(n)))

  defp compile_option([{:valtype, t}|rest], opt)
    when t in [:boolean, :integer, :float, :string],
    do: compile_option(rest, %{opt | valtype: t})

  defp compile_option([{:multival, kind}|rest], opt)
    when kind in [:overwrite, :keep, :accumulate, :error],
    do: compile_option(rest, Map.put(opt, :multival, kind))

  defp compile_option([{:required, r}|rest], opt) when r in [true, false],
    do: compile_option(rest, %{opt | required: r})

  defp compile_option([{:help, h}|rest], opt) when is_binary(h),
    do: compile_option(rest, %{opt | help: h})

  defp compile_option([opt|_], _) do
    raise ArgumentError, message: "Unrecognized option parameter #{inspect opt}"
  end


  @help_cmd_spec Map.merge(@cmd_arg_defaults, %{
    name: "help",
    help: "Print description of the given command.",
    arguments: [
      Map.merge(@cmd_arg_defaults, %{
        name: "command",
        optional: true,
        help: "The command to describe. When omitted, help for the tool itself is printed."
      })
    ],
  })

  defp compile_command(:help), do: @help_cmd_spec

  defp compile_command(cmd), do: compile_command(cmd, @cmd_arg_defaults)

  defp compile_command([], cmd), do: cmd

  defp compile_command([{:name, n}|rest], cmd) when is_binary(n),
    do: compile_command(rest, Map.put(cmd, :name, n))

  defp compile_command([{:help, h}|rest], cmd) when is_binary(h),
    do: compile_command(rest, %{cmd | help: h})

  defp compile_command([{:arguments, arg}|rest], cmd) when is_list(arg),
    do: compile_command(rest, Map.put(cmd, :arguments, process_arguments(arg)))

  defp compile_command([{:options, opt}|rest], cmd) when is_list(opt),
    do: compile_command(rest, Map.put(cmd, :options, process_options(opt)))

  defp compile_command([opt|_], _) do
    raise ArgumentError, message: "Unrecognized command parameter #{inspect opt}"
  end


  defp compile_argument(arg), do: compile_argument(arg, @cmd_arg_defaults)

  defp compile_argument([], arg), do: arg

  defp compile_argument([{:name, n}|rest], arg) when is_binary(n),
    do: compile_argument(rest, Map.put(arg, :name, parse_argname(n)))

  defp compile_argument([{:help, h}|rest], arg) when is_binary(h),
    do: compile_argument(rest, %{arg | help: h})

  defp compile_argument([{:optional, o}|rest], arg) when o in [true, false],
    do: compile_argument(rest, %{arg | optional: o})

  defp compile_argument([opt|_], _) do
    raise ArgumentError, message: "Unrecognized argument parameter #{inspect opt}"
  end


  defp parse_argname(name), do: name
    #name_re     = ~r/^[[:alpha:]]+$/
    #opt_name_re = ~r/^\[([[:alpha:]]+)\]$/

    #{name, optional} = case Regex.run(name_re, name) do
      #[^name] ->
        #{name, false}

      #nil ->
        #case Regex.run(opt_name_re, name) do
          #[^name, name] ->
            #{name, true}

          #nil -> raise ArgumentError, message: "Bad syntax in argument name: #{inspect name}"
        #end
    #end

    #map
    #|> Map.put(key, name)
    #|> Map.put(:optional, optional)
  #end


  defp validate_spec(spec=%{}) do
    if spec[:name] == nil do
      msg = "Missing :name option for the command"
      raise ArgumentError, message: msg
    end
    if spec[:usage] != nil and spec[:help] != nil do
      msg = "Options :usage and :help are incompatible with each other"
      raise ArgumentError, message: msg
    end
    if spec[:commands] != nil and spec[:arguments] != nil do
      msg = "Options :commands and :arguments are incompatible with each other"
      raise ArgumentError, message: msg
    end
    if spec[:usage] == nil and spec[:help] == nil, do:
      spec = Map.put(spec, :help, "")
    spec
  end

  defp validate_option(opt=%{}) do
    name = opt[:name]
    if name == nil and opt[:short] == nil do
      msg = "Option should have at least one of :name or :short: #{inspect opt}"
      raise ArgumentError, message: msg
    end
    if opt[:argname] == nil and opt[:valtype] != :boolean and name != nil do
      opt = Map.put(opt, :argname, name)
    end
    opt
  end

  defp validate_argument(arg=%{}) do
    if arg[:name] == nil do
      arg = Map.put(arg, :name, "arg")
    end
    arg
  end

  defp validate_arguments(args) do
    Enum.reduce(args, false, fn arg, seen_optional? ->
      if !arg[:optional] && seen_optional? do
        raise ArgumentError, message: "Required arguments cannot follow optional ones"
      end
      seen_optional? || arg[:optional]
    end)
    args
  end

  defp validate_command(cmd=%{}) do
    if !cmd[:name] do
      msg = "Expected command to have a name: #{inspect cmd}"
      raise ArgumentError, message: msg
    end
    cmd
  end

  ###

  defp spec_to_parser_opts(spec=%{options: opt}) do
    Enum.reduce(opt, {[], []}, fn opt, {switches, aliases} ->
      IO.puts "transformng opt #{inspect opt}"

      opt_name = opt_name_to_atom(opt)
      kind = []

      if valtype=opt[:valtype], do:
        kind = [valtype|kind]
      case opt[:multival] do
        default when default in [nil, :overwrite] ->
          nil
        keep when keep in [:keep, :accumulate, :error] ->
          kind = [:keep|kind]
      end
      if kind != [], do:
        switches = [{opt_name, kind}|switches]

      if short=opt[:short], do:
        aliases = [{binary_to_atom(short), opt_name}|aliases]

      {switches, aliases}
    end)
  end

  defp postprocess_opts_and_args(spec, opts, args) do
    IO.puts "Post-processing #{inspect opts} and #{inspect args}"

    # 1. Check if there are any extraneous switches
    option_set = Enum.map(spec[:options], &opt_name_to_atom/1) |> Enum.into(%{})
    Enum.each(opts, fn {name, _} ->
      if !option_set[name] do
        raise RuntimeError, message: "Unrecognized option: #{inspect name}"
      end
    end)

    # 2. Check all options for consistency with the spec
    # 3. Check arguments
    case check_argument_count(spec, args) do
      {:extra, index} ->
        raise RuntimeError, message: "Unexpected argument: #{Enum.at(args, index)}"

      {:missing, index} ->
        name = Enum.at(spec[:arguments], index)[:name]
        raise RuntimeError, message: "Missing required argument: <#{name}>"

      nil -> nil
    end
    # 4. If it is a command, continue parsing the command

    %Commando.Cmd{
      options: opts,
      arguments: args,
    }
  end


  defp opt_name_to_atom(opt),
    do: binary_to_atom(opt[:name] || opt[:short])

  defp check_argument_count(%{arguments: arguments}, args)
    when is_list(arguments)
  do
    {required_cnt, optional_cnt} = Enum.reduce(arguments, {0, 0}, fn
      %{optional: true}, {req_cnt, opt_cnt} -> {req_cnt, opt_cnt+1}
      _, {req_cnt, opt_cnt} -> {req_cnt + 1, opt_cnt}
    end)
    given_cnt = length(args)
    cond do
      given_cnt > required_cnt + optional_cnt ->
        {:extra, required_cnt + optional_cnt}

      given_cnt < required_cnt ->
        {:missing, given_cnt}

      true -> nil
    end
  end

  defp check_argument_count(_, []), do: nil

  defp check_argument_count(_, _), do: {:extra, 0}
end
