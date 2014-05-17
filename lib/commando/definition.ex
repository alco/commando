defmodule Commando.Definition do
  @moduledoc false

  # Private module responsible for processing the command definition to produce
  # a validated command specification that is later used in calls to parse(),
  # help(), and usage() functions

  @spec_defaults %{
    prefix: "",
    help: "",
    options: [],
  }

  @opt_defaults %{
    valtype: :string,
    required: false,
    help: "",
  }

  @arg_defaults %{
    valtype: :string,
    required: true,
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
        required: false,
        help: "The command to describe. When omitted, help for the tool itself is printed."
      })
    ],
  })


  import Commando.Util, only: [config_error: 1]


  def compile(spec) do
    process_definition(spec, @spec_defaults) |> validate_spec()
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

  defp process_options(opt) do
    Enum.map(opt, &(compile_option(&1) |> validate_option()))
    |> validate_options()
  end

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
      {:short, <<_>>=s} ->
        Map.put(opt, :short, s)

      {:argname, n} when is_binary(n) ->
        Map.put(opt, :argname, n)

      other ->
        compile_argument([other], opt)
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

      {:action, a} when is_function(a, 2) ->
        Map.put(cmd, :action, a)

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

      {:valtype, t} when t in [:boolean, :integer, :float, :string] ->
        %{arg | valtype: t}

      {:multival, kind} when kind in [:overwrite, :keep, :accumulate, :error] ->
        Map.put(arg, :multival, kind)

      {:required, r} when r in [true, false] ->
        %{arg | required: r}

      {:help, h} when is_binary(h) ->
        %{arg | help: h}

      {:default, val} ->
        Map.put(arg, :default, val)

      opt ->
        config_error("Unrecognized parameter #{inspect opt}")
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
    if arg[:default] && arg[:required] do
      config_error("Argument parameter :default implies required=false")
    end
    arg
  end

  defp validate_arguments(args) do
    Enum.reduce(args, false, fn arg, seen_optional? ->
      if arg[:required] && seen_optional? do
        config_error("Required arguments cannot follow optional ones")
      end
      seen_optional? || !arg[:required]
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


  defp validate_options(opts) do
    Enum.reduce(opts, %{}, fn opt, set ->
      {name, short} = {opt[:name], opt[:short]}
      if name && set[name] do
        config_error("Duplicate option name: #{name}")
      end
      if short && set[short] do
        config_error("Duplicate option name: #{short}")
      end
      set |> Map.put(name, true) |> Map.put(short, true)
    end)
    opts
  end
end
