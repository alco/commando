defmodule Commando do
  @spec_defaults %{
    width: 40,
    options: [],
    commands: [],
  }

  @opt_defaults %{
    help: "",
  }

  @cmd_defaults %{
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
  end

  @doc """
  Print usage text for the spec or one of its subcommands.
  """
  def usage(spec, cmd \\ nil) do
  end

  ###

  defp process_definition([], spec), do: spec

  defp process_definition([{:width, w}|rest], spec) when is_integer(w), do:
    process_definition(rest, %{spec | width: w})

  defp process_definition([{:usage, u}|rest], spec) when is_binary(u), do:
    process_definition(rest, Map.put(spec, :usage, u))

  defp process_definition([{:help, h}|rest], spec) when is_binary(h), do:
    process_definition(rest, Map.put(spec, :help, h))

  defp process_definition([{:arguments, arg}|rest], spec) when is_list(arg), do:
    process_definition(rest, %{spec | arguments: process_arguments(arg)})

  defp process_definition([{:options, opt}|rest], spec) when is_list(opt), do:
    process_definition(rest, %{spec | options: process_options(opt)})

  defp process_definition([{:commands, cmd}|rest], spec) when is_list(cmd), do:
    process_definition(rest, %{spec | options: process_commands(cmd)})

  defp process_definition([opt|_], _) do
    raise ArgumentError, message: "Unrecognized option #{inspect opt}"
  end


  defp process_options(opt), do: Enum.map(opt, &(compile_option(&1) |> validate_option()))

  defp process_commands(cmd), do: Enum.map(cmd, &(compile_command(&1) |> validate_command()))

  defp process_arguments(arg), do: Enum.map(arg, &(compile_argument(&1) |> validate_argument()))


  defp compile_option(opt), do: compile_option(opt, @opt_defaults)

  defp compile_option([], opt), do: opt

  defp compile_option([{:name, <<_, _, _::binary>>=n}|rest], opt), do:
    compile_option(rest, Map.put(opt, :name, n))

  defp compile_option([{:short, <<_>>=s}|rest], opt), do:
    compile_option(rest, Map.put(opt, :short, s))

  defp compile_option([{:argname, n}|rest], opt) when is_binary(n), do:
    compile_option(rest, Map.put(opt, :argname, process_arg_name(n)))

  defp compile_option([{:help, h}|rest], opt) when is_binary(h), do:
    compile_option(rest, %{opt | help: h})

  defp compile_option([opt|_], _) do
    raise ArgumentError, message: "Unrecognized option parameter #{inspect opt}"
  end


  defp compile_command(cmd), do: compile_command(cmd, @cmd_defaults)

  defp compile_command([], cmd), do: cmd

  defp compile_command([{:name, n}|rest], cmd) when is_binary(n), do:
    compile_command(rest, Map.put(cmd, :name, n))

  defp compile_command([{:help, h}|rest], cmd) when is_binary(h), do:
    compile_command(rest, %{cmd | help: h})

  defp compile_command([{:arguments, arg}|rest], cmd) when is_list(arg), do:
    compile_command(rest, Map.put(cmd, :arguments, process_arguments(arg)))

  defp compile_command([{:options, opt}|rest], cmd) when is_list(opt), do:
    compile_command(rest, Map.put(cmd, :options, process_options(opt)))

  defp compile_command([opt|_], _) do
    raise ArgumentError, message: "Unrecognized command parameter #{inspect opt}"
  end


  defp compile_argument(arg), do: compile_argument(arg, %{})

  defp compile_argument([], arg), do: arg

  defp compile_argument([{:name, n}|rest], arg) when is_binary(n), do:
    compile_argument(rest, Map.put(arg, :name, process_arg_name(n)))

  defp compile_argument([opt|_], _) do
    raise ArgumentError, message: "Unrecognized argument parameter #{inspect opt}"
  end


  defp process_arg_name(name) do
    name_re     = ~r/^[[:alpha:]]+$/
    opt_name_re = ~r/^\[([[:alpha:]]+)\]$/

    case Regex.run(name_re, name) do
      [^name] ->
        {name, :required}

      nil ->
        case Regex.run(opt_name_re, name) do
          [^name, name] ->
            {name, :optional}

          nil -> raise ArgumentError, message: "Bad syntax in argument name: #{inspect name}"
        end
    end
  end


  defp validate_argument(arg=%{}) do
    if !arg[:name] do
      arg = Map.put(arg, :name, {"arg", :required})
    end
    arg
  end

  defp validate_option(opt=%{}) do
    if opt[:name] == nil and opt[:short] == nil do
      raise ArgumentError, message: "Option should have at least one of :name or :short: #{inspect opt}"
    end
    opt
  end

  defp validate_command(cmd=%{}) do
    if !cmd[:name] do
      raise ArgumentError, message: "Expected command to have a name: #{inspect cmd}"
    end
    cmd
  end

  defp validate_spec(spec=%{}) do
    if spec[:usage] != nil and spec[:help] != nil do
      raise ArgumentError, message: "Options :usage and :help are incompatible with each other"
    end
    if spec[:commands] != nil and spec[:arguments] != nil do
      raise ArgumentError, message: "Options :commands and :arguments are incompatible with each other"
    end
    if spec[:usage] == nil and spec[:help] == nil do
      spec = Map.put(spec, :help, "")
    end
    spec
  end
end
