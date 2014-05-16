defmodule Commando.Util do
  @moduledoc false

  @config_default %{
    halt: true,
    report_errors: :report,
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

      {:on_error, val} when val in [:report, :return] ->
        Map.put(config, :format_errors, val)

      #{:on_error, {f, _state}=handler} when is_function(f, 2) ->
        #Map.put(config, :error_handler, handler)

      opt ->
        config_error("Unrecognized config option #{inspect opt}")
    end
    compile_config(config, rest)
  end


  defp compile_autoexec_param(config, param) do
    case param do
      flag when flag in [true, false] ->
        Map.merge(config, %{exec_help: flag, exec_version: flag})

      :help ->
        Map.put(config, :exec_help, true)

      :version ->
        Map.put(config, :exec_version, true)

      list when is_list(list) ->
        Enum.reduce(list, config, fn
          p, config when p in [:help, :version] -> compile_autoexec_param(config, p)
          other, _ -> config_error("Invalid :autoexec parameter value: #{other}")
        end)
    end
  end

  ###

  def name_to_opt(name), do: String.replace(name, "_", "-")

  ###

  def config_error(msg) do
    throw {:config_error, msg}
  end

  ###

  def command_exists?(spec, name) do
    if cmd_spec=Enum.find(spec[:commands], &( &1[:name] == name )) do
      cmd_spec
    end
  end
end
