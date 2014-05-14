defmodule Commando.Definition do
  @moduledoc false

  # Private module responsible for processing the command definition to produce
  # a validated command specification that is later used in calls to parse(),
  # help(), and usage() functions

  @spec_defaults %{
    prefix: "",
    help: "",
    exec_help: false,
    exec_version: false,
    options: [],
    halt: true,
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

  ###

  def compile(spec, config) do
    spec = process_definition(spec, @spec_defaults) |> validate_spec()
    process_config(config, spec)
  end

  ###

  defp process_definition([], spec), do: spec

  defp process_definition([{:name, n}|rest], spec) when is_binary(n),
    do: process_definition(rest, Map.put(spec, :name, n))

  defp process_definition([{:prefix, p}|rest], spec) when is_binary(p),
    do: process_definition(rest, %{spec | prefix: p})

  defp process_definition([{:version, v}|rest], spec) when is_binary(v),
    do: process_definition(rest, Map.put(spec, :version, v))

  defp process_definition([{:usage, u}|rest], spec) when is_binary(u),
    do: process_definition(rest, Map.put(spec, :usage, u))

  defp process_definition([{:help, h}|rest], spec) when is_binary(h),
    do: process_definition(rest, %{spec | help: h})

  defp process_definition([{:help, {:full, h}=hh}|rest], spec) when is_binary(h),
    do: process_definition(rest, %{spec | help: hh})

  defp process_definition([{:help_option, val}|rest], spec)
    when val in [:top_cmd, :all_cmd],
    do: process_definition(rest, Map.put(spec, :help_option, val))

  defp process_definition([{:options, opt}|rest], spec) when is_list(opt),
    do: process_definition(rest, %{spec | options: process_options(opt)})

  defp process_definition([{:list_options, kind}|rest], spec)
    when kind in [nil, :short, :long, :all],
    do: process_definition(rest, Map.put(spec, :list_options, kind))

  defp process_definition([{:arguments, arg}|rest], spec) when is_list(arg),
    do: process_definition(rest, Map.put(spec, :arguments, process_arguments(arg)))

  defp process_definition([{:commands, cmd}|rest], spec) when is_list(cmd),
    do: process_definition(rest, Map.put(spec, :commands, process_commands(spec, cmd)))

  defp process_definition([opt|_], _) do
    config_error("Unrecognized option #{inspect opt}")
  end

  ###

  defp process_config([], spec), do: spec

  defp process_config([{:autoexec, val}|rest], spec),
    do: process_config(rest, compile_autoexec_param(spec, val))

  defp process_config([{:halt, val}|rest], spec)
    when val in [true, false, :exit],
    do: process_config(rest, Map.put(spec, :halt, val))

  defp process_config([{:format_errors, flag}|rest], spec)
    when flag in [true, false],
    do: process_config(rest, Map.put(spec, :format_errors, flag))

  defp process_config([opt|_], _) do
    config_error("Unrecognized config option #{inspect opt}")
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
          other, _ -> config_error("Invalid :autoexec parameter value: #{other}")
        end)

  ###

  defp process_options(opt),
    do: (Enum.map(opt, &(compile_option(&1) |> validate_option())))

  defp process_commands(spec, cmd),
    do: Enum.map(cmd, &(compile_command(&1) |> validate_command(spec)))

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
    do: compile_option(rest, Map.put(opt, :argname, n))

  defp compile_option([{:valtype, t}|rest], opt)
    when t in [:boolean, :integer, :float, :string],
    do: compile_option(rest, %{opt | valtype: t})

  defp compile_option([{:default, val}|rest], opt),
    #when t in [:boolean, :integer, :float, :string],
    do: compile_option(rest, Map.put(opt, :default, val))

  defp compile_option([{:multival, kind}|rest], opt)
    when kind in [:overwrite, :keep, :accumulate, :error],
    do: compile_option(rest, Map.put(opt, :multival, kind))

  defp compile_option([{:required, r}|rest], opt) when r in [true, false],
    do: compile_option(rest, %{opt | required: r})

  defp compile_option([{:help, h}|rest], opt) when is_binary(h),
    do: compile_option(rest, %{opt | help: h})

  defp compile_option([opt|_], _) do
    config_error("Unrecognized option parameter #{inspect opt}")
  end


  defp compile_command(:help), do: @help_cmd_spec

  defp compile_command(cmd), do: compile_command(cmd, @cmd_defaults)

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
    config_error("Unrecognized command parameter #{inspect opt}")
  end


  defp compile_argument(arg), do: compile_argument(arg, @arg_defaults)

  defp compile_argument([], arg), do: arg

  defp compile_argument([{:name, n}|rest], arg) when is_binary(n),
    do: compile_argument(rest, Map.put(arg, :name, n))

  defp compile_argument([{:help, h}|rest], arg) when is_binary(h),
    do: compile_argument(rest, %{arg | help: h})

  defp compile_argument([{:optional, o}|rest], arg) when o in [true, false],
    do: compile_argument(rest, %{arg | optional: o})

  defp compile_argument([{:default, val}|rest], arg),
    do: compile_argument(rest, Map.put(arg, :default, val))

  defp compile_argument([opt|_], _) do
    config_error("Unrecognized argument parameter #{inspect opt}")
  end

  ###

  defp validate_spec(spec=%{}) do
    if spec[:name] == nil do
      config_error("Missing :name option for the command")
    end
    if spec[:commands] != nil and spec[:arguments] != nil do
      config_error("Options :commands and :arguments are mutually exclusive")
    end
    if spec[:help_option] do
      spec = Map.update!(spec, :options, &[@help_opt_spec|&1])
    end
    spec
  end

  defp validate_option(opt=%{}) do
    name = opt[:name]
    if name == nil and opt[:short] == nil do
      config_error("Option #{inspect opt} should have :name or :short or both")
    end
    if opt[:argname] == nil and opt[:valtype] != :boolean and name != nil do
      opt = Map.put(opt, :argname, name)
    end
    if opt[:default] && opt[:required] do
      config_error("Incompatible option parameters: :default and :required")
    end
    opt
  end

  defp validate_argument(arg=%{}) do
    if arg[:name] == nil do
      arg = Map.put(arg, :name, "arg")
    end
    if arg[:default] && !arg[:optional] do
      config_error("Argument parameter :default implies optional=true")
    end
    arg
  end

  defp validate_arguments(args) do
    Enum.reduce(args, false, fn arg, seen_optional? ->
      if !arg[:optional] && seen_optional? do
        config_error("Required arguments cannot follow optional ones")
      end
      seen_optional? || arg[:optional]
    end)
    args
  end

  defp validate_command(cmd=%{}, spec) do
    if !cmd[:name] do
      config_error("Expected command #{inspect cmd} to have a name")
    end
    if spec[:help_option] == :all_cmd, do:
      cmd = Map.update!(cmd, :options, &[@help_opt_spec|&1])
    cmd
  end

  ###

  defp config_error(msg) do
    throw {:config_error, msg}
  end
end
