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
    required: false,
    help: "",
  }

  @arg_defaults %{
    required: true,
    help: "",
  }

  @cmd_defaults %{
    options: [],
    help: "",
  }

  @help_opt_spec %{
    argtype: :boolean,
    required: false,
    help: "Print description of the command.",
    short: "h",
    name: "help",
  }

  @version_opt_spec %{
    argtype: :boolean,
    required: false,
    help: "Print version information and exit.",
    short: "v",
    name: "version",
  }

  @help_cmd_spec Map.merge(@cmd_defaults, %{
    name: "help",
    argname: "help",
    help: "Print description of the given command.",
    arguments: [
      Map.merge(@arg_defaults, %{
        name: "command",
        argname: "command",
        required: false,
        help: "The command to describe. When omitted, help for the tool itself is printed."
      })
    ],
  })


  alias Commando.Util
  import Util, only: [config_error: 1]


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

  defp process_arguments(arg) do
    Enum.map(arg, &(compile_argument(&1) |> validate_argument()))
    |> validate_arguments()
  end

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

      {:multival, kind} when kind in [:overwrite, :keep, :accumulate, :error] ->
        Map.put(opt, :multival, kind)

      {:target, name} when is_binary(name) ->
        Map.put(opt, :target, name)

      {:hidden, flag} when flag in [true, false] ->
        Map.put(opt, :hidden, flag)

      {:store, {:const, _}=s} ->
        Map.put(opt, :store, s)

      {:store, :self} ->
        Map.put(opt, :store, :self)

      # :action: :store, {:store, val}, :accumulate, :keep
      #          :error?

      {:nargs, _} ->
        config_error("Invalid option parameter: nargs")

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

      {:argname, n} when is_binary(n) ->
        Map.put(arg, :argname, n)

      {:argtype, t} ->
        case parse_arg_type(t) do
          :error ->
            config_error("Bad parameter value for :argtype: #{inspect t}")
          {typ, :optional} ->
            Map.merge(arg, %{argtype: typ, argoptional: true})
          typ ->
            Map.put(arg, :argtype, typ)
        end

      {:nargs, n} when n in [:inf] ->
        Map.put(arg, :nargs, n)

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

  defp parse_arg_type([typ, :optional]) do
    case parse_arg_type(typ) do
      :error -> :error
      other -> {other, :optional}
    end
  end

  defp parse_arg_type(typ) do
    case typ do
      t when t in [:boolean, :integer, :float, :string] ->
        t

      {:choice, vals} when is_list(vals) ->
        {:choice, :string, vals}

      {:choice, typ, vals}=t
          when is_list(vals)
           and typ in [:boolean, :integer, :float, :string] ->
        t

      _ -> :error
    end
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
    if opt[:argname] == nil and opt[:argtype] != :boolean and name != nil do
      opt = Map.put(opt, :argname, name)
    end
    if opt[:default] && opt[:required] do
      config_error("Incompatible option parameters: :default and :required")
    end
    if opt[:store] do
      if opt[:argtype] do
        config_error("Option parameter :argtype is incompatible with :store")
      end
    else
      if opt[:argtype] == nil do
        opt = Map.put(opt, :argtype, :string)
      end
    end
    opt
  end

  defp validate_argument(arg=%{}) do
    name = arg[:name]
    if name == nil do
      name = "arg"
      arg = Map.put(arg, :name, name)
    end
    if arg[:argname] == nil do
      arg = Map.put(arg, :argname, name)
    end
    if arg[:default] && arg[:required] do
      config_error("Argument parameter :default implies required=false")
    end
    if arg[:argtype] == nil do
      arg = Map.put(arg, :argtype, :string)
    end
    arg
  end

  defp validate_arguments(args) do
    {_, seen_glob?, last_arg} =
      Enum.reduce(args, {%{}, false, nil}, fn arg, {set, seen_glob?, _} ->
        if seen_glob? do
          config_error("No arguments can follow the vararg one")
        end
        name = arg[:name]
        if set[name] do
          config_error("Duplicate argument name: #{name}")
        end

        {Map.put(set, name, true), seen_glob? or Util.is_glob_arg(arg), arg}
      end)
    if seen_glob? and not Util.is_glob_arg(last_arg) do
      config_error("Vararg argument has to be the last one")
    end
    args
  end

  defp validate_command(cmd=%{}, spec) do
    name = cmd[:name]
    if name == nil do
      config_error("Expected command #{inspect cmd} to have a name")
    end
    if cmd[:argname] == nil do
      cmd = Map.put(cmd, :argname, name)
    end
    if spec[:help_option] == :all_cmd do
      cmd = Map.update!(cmd, :options, &[@help_opt_spec|&1])
    end
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
