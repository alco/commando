defmodule Commando.Util do
  @moduledoc false

  @parse_config %{
    halt: :return,
    format_errors: :return,
    exec_actions: false,
    exec_version: false,
    exec_help: false,
  }

  @exec_config_default %{
    halt: true,
    format_errors: :report,
    exec_actions: true,
    exec_version: true,
    exec_help: true,
  }

  def parse_config, do: @parse_config

  def compile_exec_config(opts, spec),
    do: compile_exec_config(@exec_config_default, opts, spec)

  defp compile_exec_config(config, [], spec), do: {config, spec}

  defp compile_exec_config(config, [param|rest], spec) do
    config = case param do
      {:halt, val} when val in [true, :exit, :return] ->
        Map.put(config, :halt, val)

      {:on_error, val} when val in [:report, :raise] ->
        Map.put(config, :format_errors, val)

      #{:on_error, {f, _state}=handler} when is_function(f, 2) ->
        #Map.put(config, :error_handler, handler)

      {:actions, val} when is_list(val) ->
        spec = compile_actions(val, spec)
        config

      opt ->
        config_error("Unrecognized config option #{inspect opt}")
    end
    compile_exec_config(config, rest, spec)
  end

  defp compile_actions(action_spec, spec) do
    Enum.reduce(action_spec, spec, fn
      {:commands, map}, spec when is_map(map) ->
        compile_command_actions(map, spec)
      {:options, map}, spec when is_map(map) ->
        compile_option_actions(map, spec)
      key, _ ->
        config_error("Invalid action entry: #{inspect key}")
    end)
  end

  defp compile_command_actions(map, spec) do
    Enum.reduce(map, spec, fn
      {key, val}, spec when is_binary(key) and is_function(val, 2) ->
        index = Enum.find_index(spec.commands, &(&1.name == key))
        if !index do
          config_error("Unrecognized command: #{key}")
        end
        cmdspec = Enum.at(spec.commands, index)
        Map.update!(spec, :commands, fn list ->
          List.replace_at(list, index, Map.put(cmdspec, :action, val))
        end)
        #put_in(spec.commands[index][:action], val)
      other, _ ->
        config_error("Invalid command action entry: #{inspect other}")
    end)
  end

  defp compile_option_actions(_map, spec) do
    spec
  end

  ###

  def config_error(msg) do
    throw {:config_error, msg}
  end

  ###

  def command_if_exists(%{commands: commands}, name) when is_list(commands) do
    Enum.find(commands, &( &1[:name] == name ))
  end

  def command_if_exists(_, _), do: nil

  ###

  def format_error(reason) do
    case reason do
      {:bad_opt, name} ->
        "Unrecognized option: #{name}"

      {:missing_opt, name} ->
        "Missing required option: #{opt_name_to_bin(name)}"

      {:missing_opt_arg, name} ->
        "Missing argument for option: #{name}"

      {:bad_opt_value, {name, val}} ->
        "Bad option value for #{name}: #{val}"

      {:bad_opt_choice, {name, val, values}} ->
        values_str = join(values, ", ")
        "Bad option value for #{opt_name_to_bin(name)}: #{val}. Has to be one of: #{values_str}"

      {:duplicate_opt, name} ->
        "Error trying to overwrite the value for option #{opt_name_to_bin(name)}"

      {:bad_arg, name} ->
        "Unexpected argument: #{name}"

      {:bad_arg_value, {name, val}} ->
        "Bad argument value for <#{name}>: #{val}"

      {:bad_arg_choice, {name, val, values}} ->
        values_str = join(values, ", ")
        "Bad argument value for <#{name}>: #{val}. Has to be one of: #{values_str}"

      {:missing_arg, name} ->
        "Missing required argument: <#{name}>"

      :missing_cmd ->
        "Missing command"

      {:bad_cmd, name} ->
        "Unrecognized command: #{name}"

      _ -> inspect(reason)
    end
  end

  def opt_name_to_binopt(name),
    do: name |> atom_to_binary() |> String.replace("_", "-")

  def opt_name_to_bin(name) do
    bin = opt_name_to_binopt(name)
    if String.length(bin) == 1 do
      "-" <> bin
    else
      "--" <> bin
    end
  end

  ##

  def is_glob_arg(arg_spec) do
    arg_spec[:nargs] == :inf
  end

  ##

  def join(list, sep \\ "") do
    list
    |> Enum.drop_while(&match?("", &1))
    |> Enum.join(sep)
  end

  ##

  def info(text) do
    IO.puts IO.ANSI.escape(text)
  end

  def error(text) do
    IO.puts :stderr, IO.ANSI.escape("%{red,bright}#{text}")
  end
end
