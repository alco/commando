defmodule Commando.Parser do
  @moduledoc false

  alias Commando.Cmd
  alias Commando.Util

  def parse(args, spec, config) do
    try do
      {:ok, do_parse(args, spec, config)}
    catch
      :throw, {:parse_error, :missing_cmd=reason} ->
        if config[:exec_help] and (has_help_cmd(spec) or has_help_opt(spec)) do
          IO.puts Commando.help(spec)
          halt(config, 2)
        else
          process_error(reason, config)
        end

      :throw, {:parse_error, reason} ->
        process_error(reason, config)
    end
  end

  defp process_error(reason, config) do
    case config[:format_errors] do
      :return -> {:error, reason}
      :raise -> raise RuntimeError, message: Util.format_error(reason)
      :report ->
        IO.puts Util.format_error(reason)
        halt(config, 1)
    end
  end

  ###

  defp do_parse(args, spec, config) do
    {switches, aliases} = spec_to_parser_opts(spec)
    commands = spec[:commands]
    parse_head? = is_list(commands) and commands != []
    parser_config = [strict: switches, aliases: aliases]

    {opts, args} = case do_parse_internal(args, {parser_config, not parse_head?}, {spec, config}) do
      {opts, args, nil} ->
        {process_opts(opts, spec, config), process_args(args, spec)}

      {_, _, invalid} ->
        throw parse_error(process_invalid_opt(invalid))
    end

    topcmd = %Commando.Cmd{
      name: spec[:name],
      options: opts,
    }

    if spec[:commands] do
      case parse_cmd(args, spec, config) do
        {:ok, cmd} ->
          topcmd = %Cmd{topcmd | subcmd: cmd}
          cmd_spec = Enum.find(spec[:commands], fn cmd_spec ->
            cmd_spec.name == cmd.name
          end)
          execute_cmd_if_needed(topcmd, cmd_spec, spec, config)

        {:error, reason} -> throw parse_error(reason)
      end
    else
      args = assign_args(args, spec)
      topcmd = %Cmd{topcmd | arguments: args}
    end

    topcmd
  end

  defp check_opt_error(opts, f) do
    case f.(opts) do
      {opts, []} -> opts
      {_, [bad|_]} -> throw parse_error(bad)
    end
  end

  ###

  defp spec_to_parser_opts(%{options: options}) do
    Enum.reduce(options, {[], []}, fn opt, {switches, aliases} ->
      opt_name = opt_name(opt)

      kind = unless opt[:argoptional] do
        case opt[:argtype] do
          nil             -> []
          {:choice, t, _} -> [t]
          other           -> [other]
        end
      end

      #case opt[:multival] do
        #default when default in [nil, :overwrite] ->
          #nil
        #keep when keep in [:keep, :accumulate, :error] ->
          #kind = [:keep|kind]
      #end

      if short=opt[:short] do
        aliases = [{short, opt_name}|aliases]
      end

      if not kind in [nil, []], do: switches = [{opt_name, [:keep|kind]}|switches]

      {switches, aliases}
    end)
  end

  ###

  defp process_opts(opts, spec, config) do
    opts
    #|> check_opt_error(&filter_undefined_opts(&1, spec))
    |> check_opt_error(&validate_opts(&1, spec))
    |> postprocess_opts(spec)
    |> execute_opts_if_needed(spec, config)
  end

  #defp process_opts(_, invalid, spec, _) do
    #invalid = process_invalid_opts(invalid, spec)
    #throw parse_error(invalid)
  #end


  defp process_args(args, spec) do
    case prevalidate_args(args, spec) do
      {:ok, args} -> args

      {:error, reason} ->
        throw parse_error(reason)
    end
  end


  defp group_args(spec) do
    arguments = List.wrap(spec[:arguments])
    required = Enum.filter(arguments, &match?(%{required: true}, &1))
    req_cnt = length(required)
    glob = Enum.find(arguments, &Util.is_glob_arg/1)
    {required, req_cnt, glob}
  end

  defp arg_at_index(index, spec) do
    {required, req_cnt, glob} = group_args(spec)
    if index >= req_cnt do
      glob
    else
      Enum.at(required, index)
    end
  end

  defp assign_arg(map, arg, %{name: name}=arg_spec) do
    check_arg_type(arg, arg_spec)
    if Util.is_glob_arg(arg_spec) do
      Map.update(map, name, [arg], &( &1 ++ [arg] ))
    else
      Map.put(map, name, arg)
    end
  end

  defp assign_args(args, spec) do
    {_, req_cnt, glob} = group_args(spec)

    # The order of assigning values to arguments is as follows
    #
    #   usage: tool [o1] [o2] r1 r2 r3 [r3...]
    #
    #     r1, r2, r3, o1, o2, r3...
    #
    #   usage: tool [o1] r1 [o2] [r2...]
    #
    #     r1, o1, o2, r2...
    #

    initial_map =
      List.wrap(spec[:arguments])
      |> Enum.filter(&match?(%{default: _}, &1))
      |> Enum.map(fn %{name: name, default: val} -> {name, val} end)
      |> Enum.into(%{})

    arg_cnt = length(args)
    all_specs = List.wrap(spec[:arguments]) ++ [glob]

    {map, _, _, _} = Enum.reduce(args, {initial_map, req_cnt, arg_cnt, all_specs}, fn
      arg, {map, _, _, [arg_spec]} ->
        # glob arg
        {assign_arg(map, arg, arg_spec), 0, 0, [arg_spec]}

      arg, {map, req_cnt, arg_cnt, [%{required: true}=arg_spec|rest]} ->
        {assign_arg(map, arg, arg_spec), req_cnt-1, arg_cnt-1, rest}

      arg, {map, req_cnt, arg_cnt, [arg_spec|rest]} when arg_cnt > req_cnt ->
        {assign_arg(map, arg, arg_spec), req_cnt, arg_cnt-1, rest}

      arg, {map, req_cnt, arg_cnt, specs} ->
        [arg_spec|rest] = skip_optional(specs)
        {assign_arg(map, arg, arg_spec), req_cnt-1, arg_cnt-1, rest}
    end)

    map
  end

  defp skip_optional([%{required: true}|_]=specs), do: specs
  defp skip_optional([_|rest]), do: skip_optional(rest)


  defp check_arg_type(arg, %{name: name}=spec) do
    case spec[:argtype] do
      nil -> arg

      {:choice, typ, values} ->
        new_val = case convert_value(arg, typ) do
          :error -> throw parse_error({:bad_arg_value, {name, arg}})
          {:ok, value} -> value
        end
        unless new_val in values do
          throw parse_error({:bad_arg_choice, {name, arg, values}})
        end
        new_val

      other ->
        case convert_value(arg, other) do
          :error -> throw parse_error({:bad_arg_value, {name, arg}})
          {:ok, value} -> value
        end
    end
  end

  defp convert_value(val, :string) do
    {:ok, val}
  end

  defp convert_value(val, :boolean) do
    case val do
      t when t in [true, "true"] -> {:ok, true}
      f when f in [false, "false"] -> {:ok, false}
      _ -> :error
    end
  end

  defp convert_value(val, :integer) do
    case Integer.parse(val) do
      {value, ""} -> {:ok, value}
      _ -> :error
    end
  end

  defp convert_value(val, :float) do
    case Float.parse(val) do
      {value, ""} -> {:ok, value}
      _ -> :error
    end
  end

  ###

  defp process_invalid_opt({:undefined, opt, _}),
    do: {:bad_opt, opt}

  defp process_invalid_opt({:invalid, opt, nil}),
    do: {:missing_opt_arg, opt}

  defp process_invalid_opt({:invalid, opt, val}),
    do: {:bad_opt_value, {opt, val}}

  #defp filter_undefined_opts(opts, spec) do
    ## Check if there are any extraneous switches
    #option_set = Enum.map(spec[:options], fn opt ->
      #{opt_name(opt), true}
    #end) |> Enum.into(%{})

    #Enum.reduce(opts, {[], []}, fn {name, _}=opt, {good, bad} ->
      #if !option_set[name] do
        #bad = bad ++ [{:bad_opt, name}]
      #else
        #good = good ++ [opt]
      #end
      #{good, bad}
    #end)
  #end

  defp validate_opts(opts, spec) do
    # Check all options for consistency with the spec
    Enum.reduce(spec[:options], {opts, []}, fn opt_spec, {opts, bad} ->
      opt_name = opt_name(opt_spec)
      case Keyword.get_values(opts, opt_name) do
        [] ->
          if opt_spec[:required] do
            bad = bad ++ [missing_opt: opt_name]
          end

        values ->
          case opt_spec[:multival] do
            :error ->
              unless match?([_], values) do
                bad = bad ++ [duplicate_opt: opt_name]
                opts = Keyword.delete(opts, opt_name)
              end

            _ -> nil
          end

          case opt_spec[:argtype] do
            {:choice, _, valid_vals} ->
              bad = bad ++ Enum.reduce(values, [], fn val, acc ->
                unless val in valid_vals do
                  acc = acc ++ [bad_opt_choice: {opt_name, val, valid_vals}]
                end
                acc
              end)

            _ -> nil
          end
      end
      {opts, bad}
    end)
  end

  defp postprocess_opts(opts, spec) do
    # Add default values and accumulate repeated options
    opts = Enum.reduce(opts, [], fn {opt_name, val}, acc ->
      opt_spec = Enum.find(spec[:options], fn opt_spec ->
        opt_spec[:name] == opt_name
      end)
      if target=opt_spec[:target] do
        target_key = target
        acc = acc ++ [{target_key, val}]
      else
        acc = acc ++ [{opt_name, val}]
      end
      acc
    end)

    Enum.reduce(spec[:options], opts, fn opt_spec, opts ->
      opt_name = opt_name(opt_spec)
      if (default=opt_spec[:default]) && not Keyword.has_key?(opts, opt_name) do
        opts = opts ++ [{opt_name, default}]
      end
      case opt_spec[:multival] do
        :accumulate ->
          values = Keyword.get_values(opts, opt_name)
          if values != [] do
            check_opt_val(values, opt_spec)
            opts = Keyword.update!(opts, opt_name, fn _ -> values end)
          end

        o when o in [nil, :overwrite] ->
          val = List.last(Keyword.get_values(opts, opt_name))
          if val != nil do
            check_opt_val(val, opt_spec)
            opts = Keyword.update!(opts, opt_name, fn _ -> val end)
          end

        other when other in [:keep, :error] ->
          values = Keyword.get_values(opts, opt_name)
          check_opt_val(values, opt_spec)
          nil
      end
      opts
    end)
  end

  defp check_opt_val(values, spec) when is_list(values) do
    Enum.each(values, &check_opt_val(&1, spec))
  end

  defp check_opt_val(val, %{argtype: {:choice, _, values}}=spec) do
    unless val in values do
      throw parse_error({:bad_opt_choice, {opt_name(spec), val, values}})
    end
  end

  defp check_opt_val(_, _), do: nil

  # Execute help or version option if instructed to
  defp execute_opts_if_needed(opts, spec, config) do
    if Keyword.get(opts, :help) != nil and config[:exec_help] do
      cmd_name = spec[:name]
      if cmd_name == config[:name] do
        IO.puts Commando.help(spec)
      else
        IO.puts Commando.help(spec, cmd_name)
      end
      halt(config)
    end

    if Keyword.get(opts, :version) != nil and config[:exec_version] do
      IO.puts spec[:version]
      halt(config)
    end

    opts
  end

  defp prevalidate_args(args, spec) do
    case check_argument_count(spec, args) do
      {:extra, name} ->
        {:error, {:bad_arg, name}}

      :missing_cmd ->
        {:error, :missing_cmd}

      {:missing_arg, index} ->
        name = arg_at_index(index, spec)[:name]
        {:error, {:missing_arg, name}}

      nil ->
        {:ok, args}
    end
  end

  defp parse_cmd(args, spec, config) do
    commands = spec[:commands]
    [arg|rest_args] = args
    if cmd_spec=Enum.find(commands, fn %{name: name} -> name == arg end) do
      {:ok, do_parse(rest_args, cmd_spec, config)}
    else
      {:error, {:bad_cmd, arg}}
    end
  end

  defp execute_cmd_if_needed(%Cmd{subcmd: %Cmd{name: "help", arguments: args}},
                                      _cmd_spec, spec, %{exec_help: true}=config)
  do
    halt? = try do
      case args do
        %{"command" => cmd} ->
          IO.puts Commando.help(spec, cmd)

        %{} ->
          IO.puts Commando.help(spec)
      end
    rescue
      e in [ArgumentError] ->
        IO.puts e.message
        halt(config, 1)
    end
    if halt?, do: halt(config)
  end

  defp execute_cmd_if_needed(%Cmd{subcmd: %Cmd{}=cmd}=topcmd, %{action: f}, _, _) do
    f.(cmd, topcmd)
  end

  defp execute_cmd_if_needed(_, _, _, _), do: nil

  ###

  defp opt_name(opt), do: opt[:name] || opt[:short]

  ###

  defp halt(config, status \\ 0) do
    case config[:halt] do
      true -> System.halt(status)
      :exit -> exit({Commando, status})
    end
  end

  ###

  defp check_argument_count(%{arguments: arguments}, args) do
    {required_cnt, optional_cnt} = Enum.reduce(arguments, {0, 0}, fn
      %{nargs: :inf, required: true}, {req_cnt, _} ->
        {req_cnt+1, :infinity}
      %{nargs: :inf}, {req_cnt, _} ->
        {req_cnt, :infinity}
      %{required: false}, {req_cnt, opt_cnt} ->
        {req_cnt, opt_cnt+1}
      _, {req_cnt, opt_cnt} ->
        {req_cnt+1, opt_cnt}
    end)

    given_cnt = length(args)
    cond do
      given_cnt < required_cnt ->
        {:missing_arg, given_cnt}

      optional_cnt != :infinity and given_cnt > required_cnt + optional_cnt ->
        {:extra, Enum.at(args, required_cnt + optional_cnt)}

      true -> nil
    end
  end

  defp check_argument_count(%{commands: _}, args) do
    given_cnt = length(args)
    if given_cnt < 1 do
      :missing_cmd
    end
  end

  defp check_argument_count(_, []), do: nil

  defp check_argument_count(_, [h|_]), do: {:extra, h}


  defp has_help_cmd(spec) do
    commands = spec[:commands]
    (commands
     && Enum.find(commands, fn cmd_spec -> cmd_spec[:name] == "help" end)) != nil
  end

  defp has_help_opt(spec) do
    spec[:options] != [] and hd(spec[:options])[:name] == "help"
  end

  ###

  defp parse_error(msg) do
    {:parse_error, msg}
  end

  ###

  defp do_parse_internal(argv, config, spec) do
    do_parse_internal(argv, config, [], [], spec)
  end

  defp do_parse_internal([], _config, opts, args, _spec) do
    parse_internal_end(opts, args, nil)
  end

  defp do_parse_internal(argv, {parser_config, all}=config, opts, args, {spec, _}=speconf) do
    case OptionParser.next(argv, parser_config) do
      {:ok, option, value, rest} ->
        {option, value} = execute_opt_action({option, value}, speconf)
        do_parse_internal(rest, config, [{option, value}|opts], args, speconf)

      {:undefined, option, value, rest} ->
        binopt = binopt(option)
        opt_name = binary_to_atom(binopt)
        opt_spec = Enum.find(spec[:options], fn opt_spec ->
          opt_spec[:name] == opt_name
        end)

        if !opt_spec do
          parse_internal_end(opts, args, {:undefined, option, value})
        else
          case check_option_store(binopt, value, opt_spec[:store]) do
            {:ok, val} ->
              {option, val} = execute_opt_action({opt_name, val}, speconf)
              do_parse_internal(rest, config, [{option, val}|opts], args, speconf)

            :bad_val ->
              parse_internal_end(opts, args, {:invalid, option, value})

            nil ->
              case check_option_argument(value, opt_spec) do
                {:ok, val} ->
                  {option, val} = execute_opt_action({opt_name, val}, speconf)
                  do_parse_internal(rest, config, [{option, val}|opts], args, speconf)

                nil ->
                  parse_internal_end(opts, args, {:invalid, option, value})
              end
          end
        end

      {reason, option, value, _rest} ->
        parse_internal_end(opts, args, {reason, option, value})

      {:error, ["--"|rest]} ->
        parse_internal_end(opts, {args, rest}, nil)

      {:error, [arg|rest]} ->
        arg_spec = arg_at_index(length(args), spec)
        arg = execute_arg_action(arg, arg_spec, speconf)
        if all do
          do_parse_internal(rest, config, opts, [arg|args], speconf)
        else
          parse_internal_end(opts, {args, [arg|rest]}, nil)
        end
    end
  end

  defp binopt(option) do
    if String.contains?(option, "_") do
      throw parse_error({:bad_opt, option})
    end
    option |> String.strip(?-) |> String.replace("-", "_")
  end

  defp execute_opt_action({opt_name, value}, {spec, config}) do
    opt_spec = Enum.find(spec[:options], fn opt_spec ->
      opt_spec[:name] == opt_name
    end)
    if f=opt_spec[:action] do
      case f.({opt_name, value}, spec) do
        :halt -> halt(config, 0)
        {opt, val} ->
          opt_name = opt
          value = val
      end
    end
    {opt_name, value}
  end

  defp execute_arg_action(arg, arg_spec, {spec, config}) do
    if f=arg_spec[:action] do
      case f.({arg_spec[:name], arg}, spec) do
        :halt -> halt(config, 0)
        {:halt, status} -> halt(config, status)
        {_name, val} ->
          arg = val
      end
    end
    arg
  end

  defp check_option_store(_name, _val, nil) do
    nil
  end

  defp check_option_store(name, nil, :self) do
    {:ok, name}
  end

  defp check_option_store(_name, nil, {:const, c}) do
    {:ok, c}
  end

  defp check_option_store(_name, _val, _) do
    :bad_val
  end

  defp check_option_argument(val, %{argoptional: true}) do
    {:ok, val}
  end

  defp check_option_argument(nil, _) do
    :bad_val
  end

  defp parse_internal_end(opts, {args, rest}, invalid) do
    {Enum.reverse(opts), Enum.reverse(args, rest), invalid}
  end

  defp parse_internal_end(opts, args, invalid) do
    {Enum.reverse(opts), Enum.reverse(args), invalid}
  end
end
