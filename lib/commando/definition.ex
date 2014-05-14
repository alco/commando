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

  defp process_definition([param|rest], spec) do
    spec = case param do
      {:name, n} when is_binary(n) ->
        Map.put(spec, :name, n)

      {:prefix, p} when is_binary(p) ->
        %{spec | prefix: p}

      {:version, v} when is_binary(v) ->
        Map.put(spec, :version, v)

      {:usage, u} when is_binary(u) ->
        Map.put(spec, :usage, u)

      {:help, h} when is_binary(h) ->
        %{spec | help: h}

      {:help, {:full, h}=hh} when is_binary(h) ->
        %{spec | help: hh}

      {:help_option, val} when val in [:top_cmd, :all_cmd] ->
        Map.put(spec, :help_option, val)

      {:options, opt} when is_list(opt) ->
        %{spec | options: process_options(opt)}

      {:list_options, kind} when kind in [nil, :short, :long, :all] ->
        Map.put(spec, :list_options, kind)

      {:arguments, arg} when is_list(arg) ->
        Map.put(spec, :arguments, process_arguments(arg))

      {:commands, cmd} when is_list(cmd) ->
        Map.put(spec, :commands, process_commands(spec, cmd))

      opt ->
        config_error("Unrecognized option #{inspect opt}")
    end
    process_definition(rest, spec)
  end

  ###

  defp process_config([], spec), do: spec

  defp process_config([param|rest], spec) do
    spec = case param do
      {:autoexec, val} ->
        compile_autoexec_param(spec, val)

      {:halt, val} when val in [true, false, :exit] ->
        Map.put(spec, :halt, val)

      {:format_errors, flag} when flag in [true, false] ->
        Map.put(spec, :format_errors, flag)

      opt ->
        config_error("Unrecognized config option #{inspect opt}")
    end
    process_config(rest, spec)
  end

  ###

  defp compile_autoexec_param(spec, param) do
    case param do
      flag when flag in [true, false] ->
        Map.merge(spec, %{exec_help: flag, exec_version: flag})

      :help ->
        Map.put(spec, :exec_help, true)

      :version ->
        Map.put(spec, :exec_version, true)

      list when is_list(list) ->
        Enum.reduce(list, spec, fn
          p, spec when p in [:help, :version] -> compile_autoexec_param(spec, p)
          other, _ -> config_error("Invalid :autoexec parameter value: #{other}")
        end)
    end
  end

  ###

  defp process_options(opt),
    do: (Enum.map(opt, &(compile_option(&1) |> validate_option())))

  defp process_commands(spec, cmd),
    do: Enum.map(cmd, &(compile_command(&1) |> validate_command(spec)))

  defp process_arguments(arg),
    do: (Enum.map(arg, &(compile_argument(&1) |> validate_argument()))
         |> validate_arguments())

  ###

  defp compile_option(:version), do: @version_opt_spec

  defp compile_option({:version, kind}) when kind in [:v, :V],
    do: Map.put(@version_opt_spec, :short, atom_to_binary(kind))

  defp compile_option(opt), do: compile_option(opt, @opt_defaults)


  defp compile_option([], opt), do: opt

  defp compile_option([param|rest], opt) do
    opt = case param do
      {:name, <<_, _, _::binary>>=n} ->
        Map.put(opt, :name, n)

      {:short, <<_>>=s} ->
        Map.put(opt, :short, s)

      {:argname, n} when is_binary(n) ->
        Map.put(opt, :argname, n)

      {:valtype, t} when t in [:boolean, :integer, :float, :string] ->
        %{opt | valtype: t}

      {:default, val} ->
              #when t in [:boolean, :integer, :float, :string],
        Map.put(opt, :default, val)

      {:multival, kind} when kind in [:overwrite, :keep, :accumulate, :error] ->
        Map.put(opt, :multival, kind)

      {:required, r} when r in [true, false] ->
        %{opt | required: r}

      {:help, h} when is_binary(h) ->
        %{opt | help: h}

      opt ->
        config_error("Unrecognized option parameter #{inspect opt}")
    end
    compile_option(rest, opt)
  end


  defp compile_command(:help), do: @help_cmd_spec

  defp compile_command(cmd), do: compile_command(cmd, @cmd_defaults)


  defp compile_command([], cmd), do: cmd

  defp compile_command([param|rest], cmd) do
    cmd = case param do
      {:name, n} when is_binary(n) ->
        Map.put(cmd, :name, n)

      {:help, h}when is_binary(h) ->
        %{cmd | help: h}

      {:arguments, arg} when is_list(arg) ->
        Map.put(cmd, :arguments, process_arguments(arg))

      {:options, opt} when is_list(opt) ->
        Map.put(cmd, :options, process_options(opt))

      opt ->
        config_error("Unrecognized command parameter #{inspect opt}")
    end
    compile_command(rest, cmd)
  end


  defp compile_argument(arg), do: compile_argument(arg, @arg_defaults)


  defp compile_argument([], arg), do: arg

  defp compile_argument([param|rest], arg) do
    arg = case param do
      {:name, n} when is_binary(n) ->
        Map.put(arg, :name, n)

      {:help, h} when is_binary(h) ->
        %{arg | help: h}

      {:optional, o} when o in [true, false] ->
        %{arg | optional: o}

      {:default, val} ->
        Map.put(arg, :default, val)

      opt ->
        config_error("Unrecognized argument parameter #{inspect opt}")
    end
    compile_argument(rest, arg)
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
