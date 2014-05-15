defmodule Commando.Util do
  @moduledoc false

  def name_to_opt(name), do: String.replace(name, "_", "-")

  def compile_config(spec, []), do: spec

  def compile_config(spec, [param|rest]) do
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
    compile_config(spec, rest)
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

  def config_error(msg) do
    throw {:config_error, msg}
  end
end
