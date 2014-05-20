defmodule Commando.Util do
  @moduledoc false

  @config_default %{
    halt: true,
    format_errors: :report,
    exec_version: true,
    exec_help: true,
  }

  def compile_config(opts),
    do: compile_config(@config_default, opts)

  defp compile_config(config, []), do: config

  defp compile_config(config, [param|rest]) do
    config = case param do
      {:autoexec, val} ->
        compile_autoexec_param(config, val)

      {:halt, val} when val in [true, :exit] ->
        Map.put(config, :halt, val)

      {:on_error, val} when val in [:report, :return, :raise] ->
        Map.put(config, :format_errors, val)

      #{:on_error, {f, _state}=handler} when is_function(f, 2) ->
        #Map.put(config, :error_handler, handler)

      opt ->
        config_error("Unrecognized config option #{inspect opt}")
    end
    compile_config(config, rest)
  end


  defp compile_autoexec_param(config, param) do
    config = Map.merge(config, %{
      exec_help: false, exec_version: false
    })
    case param do
      flag when flag in [true, false] ->
        Map.merge(config, %{exec_help: flag, exec_version: flag})

      :help ->
        Map.put(config, :exec_help, true)

      :version ->
        Map.put(config, :exec_version, true)

      list when is_list(list) ->
        Enum.reduce(list, config, fn
          p, config when p in [:help, :version, :commands] ->
            compile_autoexec_param(config, p)
          other, _ -> config_error("Invalid :autoexec parameter value: #{other}")
        end)
    end
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
        "Unrecognized option: #{opt_name_to_bin(name)}"

      {:missing_opt, name} ->
        "Missing required option: #{opt_name_to_bin(name)}"

      {:missing_opt_arg, name} ->
        "Missing argument for option: #{opt_name_to_bin(name)}"

      {:bad_opt_value, {name, val}} ->
        "Bad option value for #{opt_name_to_bin(name)}: #{val}"

      {:bad_opt_choice, {name, val, values}} ->
        values_str = Enum.join(values, ", ")
        "Bad option value for #{opt_name_to_bin(name)}: #{val}. Has to be one of: #{values_str}"

      {:duplicate_opt, name} ->
        "Error trying to overwrite the value for option #{opt_name_to_bin(name)}"

      {:bad_arg, name} ->
        "Unexpected argument: #{name}"

      {:bad_arg_value, {name, val}} ->
        "Bad argument value for <#{name}>: #{val}"

      {:bad_arg_choice, {name, val, values}} ->
        values_str = Enum.join(values, ", ")
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

  defp opt_name_to_bin(name) do
    opt_name = name_to_opt(atom_to_binary(name))
    if byte_size(opt_name) > 1 do
      "--" <> opt_name
    else
      "-" <> opt_name
    end
  end

  def name_to_opt(name), do: String.replace(name, "_", "-")

  ##

  def is_glob_arg(arg_spec) do
    arg_spec[:nargs] == :inf
  end
end
