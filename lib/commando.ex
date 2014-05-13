defmodule Commando.Cmd do
  defstruct [
    name: nil,
    options: [],
    arguments: nil,
    subcmd: nil,
  ]
end

defmodule Commando do
  @spec_defaults %{
    width: 40,

    prefix: "",
    exec_help: false,
    exec_version: false,
    options: [],
  }

  @opt_defaults %{
    valtype: :string,
    required: false,
    help: "",
  }

  @arg_defaults %{
    optional: false,
    help: "",
  }

  @cmd_defaults %{
    options: [],
    help: "",
  }

  @help_opt_spec %{
    valtype: :boolean,
    required: false,
    help: "Print description of the command.",
    short: "h",
    name: "help",
  }

  @version_opt_spec %{
    valtype: :boolean,
    required: false,
    help: "Print version information and exit.",
    short: "v",
    name: "version",
  }

  @help_cmd_spec Map.merge(@cmd_defaults, %{
    name: "help",
    help: "Print description of the given command.",
    arguments: [
      Map.merge(@arg_defaults, %{
        name: "command",
        optional: true,
        help: "The command to describe. When omitted, help for the tool itself is printed."
      })
    ],
  })


  @doc """
  Create a new command specification.
  """
  def new(spec) do
    process_definition(spec, @spec_defaults) |> validate_spec()
  end

  @doc """
  Parse command-line arguments according to the spec.
  """
  def parse(spec, args \\ System.argv)

  def parse({topspec, spec}, args),
    do: parse(topspec, spec, args)

  def parse(spec, args),
    do: parse(nil, spec, args)

  defp parse(topspec, spec, args) do
    #IO.puts "PARSING topspec = #{inspect topspec}"
    opts = spec_to_parser_opts(spec)
    commands = spec[:commands]

    parsed = if is_list(commands) and commands != [] do
      OptionParser.parse_head(args, opts)
    else
      OptionParser.parse(args, opts)
    end

    {opts, args} = case parsed do
      {_, _, invalid} when invalid != [] ->
        format_invalid_opts(spec, invalid)

      {opts, ["--"|args], []} -> {opts, args}
      {opts, args, []}        -> {opts, args}
    end
    postprocess_opts_and_args(topspec, spec, opts, args)
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
      raise ArgumentError, message: "Unrecognized command: #{cmd}"
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
    if short=opt[:short] do
      name = "-#{name_to_opt(short)}"
      if argname=opt[:argname], do: name = "#{name} <#{argname}>"
      name
    end
  end

  defp format_option(opt, :long) do
    if name=opt[:name] do
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
  #defp opt_to_name(opt), do: String.replace(opt, "-", "_")


  defp wrap_option(null, _, _) when null in [nil, ""], do: ""

  defp wrap_option(formatted, %{short: _, name: _, required: true}, :all),
    do: "{#{formatted}}"

  defp wrap_option(formatted, %{required: false}, _),
    do: "[#{formatted}]"

  defp wrap_option(formatted, _, _), do: formatted


  defp format_command_brief(%{name: name, help: ""}),
    do: "  #{:io_lib.format('~-10s', [name])}(no documentation)"

  defp format_command_brief(%{name: name, help: help}),
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

  defp process_definition([{:version, v}|rest], spec) when is_binary(v),
    do: process_definition(rest, Map.put(spec, :version, v))

  defp process_definition([{:autoexec, val}|rest], spec),
    do: process_definition(rest, compile_autoexec_param(spec, val))

  defp process_definition([{:help_option, val}|rest], spec)
    when val in [:top_cmd, :all_cmd],
    do: process_definition(rest, Map.put(spec, :help_option, val))

  defp process_definition([{:exec_version, e}|rest], spec) when e in [false, true],
    do: process_definition(rest, %{spec | exec_version: e})

  defp process_definition([{:usage, u}|rest], spec) when is_binary(u),
    do: process_definition(rest, Map.put(spec, :usage, u))

  defp process_definition([{:help, h}|rest], spec) when is_binary(h),
    do: process_definition(rest, Map.put(spec, :help, h))

  defp process_definition([{:help, {:full, h}=hh}|rest], spec) when is_binary(h),
    do: process_definition(rest, Map.put(spec, :help, hh))

  defp process_definition([{:options, opt}|rest], spec) when is_list(opt),
    do: process_definition(rest, %{spec | options: process_options(spec, opt)})

  defp process_definition([{:list_options, kind}|rest], spec)
    when kind in [nil, :short, :long, :all],
    do: process_definition(rest, Map.put(spec, :list_options, kind))

  defp process_definition([{:arguments, arg}|rest], spec) when is_list(arg),
    do: process_definition(rest, Map.put(spec, :arguments, process_arguments(arg)))

  defp process_definition([{:commands, cmd}|rest], spec) when is_list(cmd),
    do: process_definition(rest, Map.put(spec, :commands, process_commands(spec, cmd)))

  defp process_definition([opt|_], _) do
    raise ArgumentError, message: "Unrecognized option #{inspect opt}"
  end


  defp compile_autoexec_param(spec, flag) when flag in [true, false],
    do: Map.merge(spec, %{exec_help: flag, exec_version: flag})

  defp compile_autoexec_param(spec, :help),
    do: Map.put(spec, :exec_help, true)

  defp compile_autoexec_param(spec, :version),
    do: Map.put(spec, :exec_version, true)

  defp compile_autoexec_param(spec, list) when is_list(list),
    do: Enum.reduce(list, spec, fn
          p, spec when p in [:help, :version] ->
            compile_autoexec_param(spec, p)
          other, _ -> raise ArgumentError, message: "Bad autoexec parameter: #{other}"
        end)


  defp process_options(spec, opt) do
    opts = Enum.map(opt, &(compile_option(&1) |> validate_option()))
    if spec[:help_option] do
      opts = [@help_opt_spec|opts]
    end
    opts
  end

  defp process_cmd_options(spec, opt) do
    opts = Enum.map(opt, &(compile_option(&1) |> validate_option()))
    if spec[:help_option] == :all_cmd do
      opts = [@help_opt_spec|opts]
    end
    opts
  end

  defp process_commands(spec, cmd),
    do: Enum.map(cmd, &(compile_command(&1, spec) |> validate_command()))

  defp process_arguments(arg),
    do: (Enum.map(arg, &(compile_argument(&1) |> validate_argument()))
         |> validate_arguments())


  defp compile_option(:version), do: @version_opt_spec

  defp compile_option({:version, kind}) when kind in [:v, :V],
    do: Map.put(@version_opt_spec, :short, atom_to_binary(kind))

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


  defp compile_command(:help, spec) do
    Map.put(@help_cmd_spec, :options, process_cmd_options(spec, []))
  end

  defp compile_command(cmd, spec), do: compile_command(cmd, @cmd_defaults, spec)

  defp compile_command([], cmd, _spec), do: cmd

  defp compile_command([{:name, n}|rest], cmd, spec) when is_binary(n),
    do: compile_command(rest, Map.put(cmd, :name, n), spec)

  defp compile_command([{:help, h}|rest], cmd, spec) when is_binary(h),
    do: compile_command(rest, %{cmd | help: h}, spec)

  defp compile_command([{:arguments, arg}|rest], cmd, spec) when is_list(arg),
    do: compile_command(rest, Map.put(cmd, :arguments, process_arguments(arg)), spec)

  defp compile_command([{:options, opt}|rest], cmd, spec) when is_list(opt),
    do: compile_command(rest, Map.put(cmd, :options, process_cmd_options(spec, opt)), spec)

  defp compile_command([opt|_], _, _) do
    raise ArgumentError, message: "Unrecognized command parameter #{inspect opt}"
  end


  defp compile_argument(arg), do: compile_argument(arg, @arg_defaults)

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

  defp spec_to_parser_opts(%{options: options}) do
    {s, a} = Enum.reduce(options, {[], []}, fn opt, {switches, aliases} ->
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
    [switches: s, aliases: a]
  end


  defp format_invalid_opts(spec, invalid) do
    option_set = Enum.reduce(spec[:options], %{}, fn opt, set ->
      if short=opt[:short], do:
        set = Map.put(set, binary_to_atom(short), true)
      if name=opt[:name], do:
        set = Map.put(set, binary_to_atom(name), true)
      set
    end)
    Enum.each(invalid, fn {name, val} ->
      formatted_name = opt_name_to_bin(name)
      cond do
        !option_set[name] ->
          raise RuntimeError, message: "Unrecognized option: #{formatted_name}"

        spec[:valtype] != :boolean and val in [false, true] ->
          raise RuntimeError, message: "Missing argument for option: #{formatted_name}"

        true ->
          raise RuntimeError, message: "Bad option value for #{formatted_name}: #{val}"
      end
    end)
  end

  defp postprocess_opts_and_args(topspec, spec, opts, args) do
    # 1. Check if there are any extraneous switches
    option_set = Enum.map(spec[:options], fn opt ->
      {opt_name_to_atom(opt), true}
    end) |> Enum.into(%{})
    Enum.each(opts, fn {name, _} ->
      if !option_set[name] do
        raise RuntimeError, message: "Unrecognized option: #{opt_name_to_bin(name)}"
      end
    end)

    # 2. Check all options for consistency with the spec
    opts = Enum.reduce(spec[:options], opts, fn opt_spec, opts ->
      opt_name = opt_name_to_atom(opt_spec)
      formatted_name = format_option_no_arg(opt_spec)
      case Keyword.get_values(opts, opt_name) do
        [] ->
          if opt_spec[:required] do
            raise RuntimeError, message: "Missing required option: #{formatted_name}"
          end

        values ->
          case opt_spec[:multival] do
            :error ->
              if not match?([_], values) do
                msg = "Error trying to overwrite the value for option #{formatted_name}"
                raise RuntimeError, message: msg
              end

            :accumulate ->
              opts = Keyword.update!(opts, opt_name, fn _ -> values end)

            _ -> nil
          end
      end
      opts
    end)

    # 2/3. Execute help or version option if instructed to
    if Keyword.get(opts, :help) != nil and (topspec || spec)[:exec_help] do
      if topspec == nil do
        IO.puts help(spec)
      else
        IO.puts help(topspec, spec[:name])
      end
      System.halt()
    end

    if Keyword.get(opts, :version) != nil and topspec == nil and spec[:exec_version] do
      IO.puts spec[:version]
      System.halt()
    end

    # 3. Check arguments
    case check_argument_count(spec, args) do
      {:extra, index} ->
        raise RuntimeError, message: "Unexpected argument: #{Enum.at(args, index)}"

      {:missing, index} ->
        cond do
          arguments=spec[:arguments] ->
            name = Enum.at(arguments, index)[:name]
            raise RuntimeError, message: "Missing required argument: <#{name}>"

          spec[:commands] ->
            if topspec == nil and spec[:exec_help] and (has_help_cmd(spec) or has_help_opt(spec)) do
              try do
                IO.puts help(spec)
              rescue
                e in [ArgumentError] ->
                  IO.puts e.message
                  System.halt(1)
              end
              System.halt()
            end
            raise RuntimeError, message: "Missing command"
        end
      nil -> nil
    end

    # 4. If it is a command, continue parsing the command
    cmd = if commands=spec[:commands] do
      [arg|rest_args] = args
      unless cmd_spec=Enum.find(commands, fn %{name: name} -> name == arg end) do
        raise RuntimeError, message: "Unrecognized command: #{arg}"
      end
      args = nil
      parse(topspec || spec, cmd_spec, rest_args)
    end

    if topspec == nil and spec[:exec_help] do
      is_help_cmd = has_help_cmd(spec) and (cmd == nil or cmd.name == "help")
      halt? = try do
        case {is_help_cmd, cmd && cmd.arguments} do
          {false, _} -> nil

          {true, [arg]} ->
            IO.puts help(spec, arg)

          {true, null} when null in [nil, []] ->
            IO.puts help(spec)
        end
      rescue
        e in [ArgumentError] ->
          IO.puts e.message
          System.halt(1)
      end
      if halt?, do: System.halt()
    end

    %Commando.Cmd{
      name: spec[:name],
      options: opts,
      arguments: args,
      subcmd: cmd,
    }
  end


  defp has_help_cmd(spec) do
    commands = spec[:commands]
    (commands
     && Enum.find(commands, fn cmd_spec -> cmd_spec[:name] == "help" end)) != nil
  end

  defp has_help_opt(spec) do
    spec[:options] != [] and hd(spec[:options])[:name] == "help"
  end


  defp format_option_no_arg(opt) do
    cond do
      name=opt[:name] ->
        "--#{name_to_opt(name)}"

      short=opt[:short] ->
        "-#{name_to_opt(short)}"

      true -> ""
    end
  end


  defp opt_name_to_atom(opt),
    do: binary_to_atom(opt[:name] || opt[:short])

  defp opt_name_to_bin(name) do
    opt_name = name_to_opt(atom_to_binary(name))
    if byte_size(opt_name) > 1 do
      "--" <> opt_name
    else
      "-" <> opt_name
    end
  end

  defp check_argument_count(%{arguments: arguments}, args) do
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

  defp check_argument_count(%{commands: _}, args) do
    required_cnt = 1
    given_cnt = length(args)
    if given_cnt < required_cnt do
      {:missing, given_cnt}
    end
  end

  defp check_argument_count(_, []), do: nil

  defp check_argument_count(_, _), do: {:extra, 0}
end
