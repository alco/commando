defmodule Commando.Parser do
  @moduledoc false

  alias Commando.Util


  def parse(spec, args, nil), do: do_parse(nil, spec, args)

  ###

  defp do_parse(topspec, spec, args) do
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

  ###

  defp spec_to_parser_opts(%{options: options}) do
    {s, a} = Enum.reduce(options, {[], []}, fn opt, {switches, aliases} ->
      opt_name = opt_name_to_atom(opt)
      kind = []

      if valtype=opt[:valtype], do: kind = [valtype|kind]

      case opt[:multival] do
        default when default in [nil, :overwrite] ->
          nil
        keep when keep in [:keep, :accumulate, :error] ->
          kind = [:keep|kind]
      end
      if kind != [], do: switches = [{opt_name, kind}|switches]

      if short=opt[:short] do
        aliases = [{binary_to_atom(short), opt_name}|aliases]
      end

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

          if default=opt_spec[:default] do
            opts = opts ++ [{opt_name, default}]
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
        IO.puts Commando.help(spec)
      else
        IO.puts Commando.help(topspec, spec[:name])
      end
      halt(topspec || spec)
    end

    if Keyword.get(opts, :version) != nil and topspec == nil and spec[:exec_version] do
      IO.puts spec[:version]
      halt(spec)
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
                IO.puts Commando.help(spec)
              rescue
                e in [ArgumentError] ->
                  IO.puts e.message
                  halt(spec, 1)
              end
              halt(spec)
            end
            raise RuntimeError, message: "Missing command"
        end

      {:add, val} ->
        args = args ++ [val]

      nil -> nil
    end

    # 4. If it is a command, continue parsing the command
    cmd = if commands=spec[:commands] do
      [arg|rest_args] = args
      unless cmd_spec=Enum.find(commands, fn %{name: name} -> name == arg end) do
        raise RuntimeError, message: "Unrecognized command: #{arg}"
      end
      args = nil
      do_parse(topspec || spec, cmd_spec, rest_args)
    end

    if topspec == nil and spec[:exec_help] do
      is_help_cmd = has_help_cmd(spec) and (cmd == nil or cmd.name == "help")
      halt? = try do
        case {is_help_cmd, cmd && cmd.arguments} do
          {false, _} -> nil

          {true, [arg]} ->
            IO.puts Commando.help(spec, arg)

          {true, null} when null in [nil, []] ->
            IO.puts Commando.help(spec)
        end
      rescue
        e in [ArgumentError] ->
          IO.puts e.message
          halt(spec, 1)
      end
      if halt?, do: halt(spec)
    end

    %Commando.Cmd{
      name: spec[:name],
      options: opts,
      arguments: args,
      subcmd: cmd,
    }
  end

  ###

  defp opt_name_to_atom(opt),
    do: binary_to_atom(opt[:name] || opt[:short])

  defp opt_name_to_bin(name) do
    opt_name = Util.name_to_opt(atom_to_binary(name))
    if byte_size(opt_name) > 1 do
      "--" <> opt_name
    else
      "-" <> opt_name
    end
  end

  ###

  defp format_option_no_arg(opt) do
    cond do
      name=opt[:name] ->
        "--#{Util.name_to_opt(name)}"

      short=opt[:short] ->
        "-#{Util.name_to_opt(short)}"

      true -> ""
    end
  end

  ###

  defp halt(spec, status \\ 0) do
    case spec[:halt] do
      true -> System.halt(status)
      :exit -> exit({Commando, status})
    end
  end

  ###

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

      arguments != [] ->
        # FIXME: half-baked solution
        default = hd(arguments)[:default]
        if given_cnt < required_cnt + optional_cnt && default do
          {:add, default}
        end

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


  defp has_help_cmd(spec) do
    commands = spec[:commands]
    (commands
     && Enum.find(commands, fn cmd_spec -> cmd_spec[:name] == "help" end)) != nil
  end

  defp has_help_opt(spec) do
    spec[:options] != [] and hd(spec[:options])[:name] == "help"
  end

end
