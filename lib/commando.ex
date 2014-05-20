defmodule Commando do
  @default_indent 2

  alias Commando.Util

  @doc """
  Create a new command specification.
  """
  def new(spec) do
    try do
      Commando.Definition.compile(spec)
    catch
      :throw, {:config_error, msg} ->
        raise ArgumentError, message: msg
    end
  end


  @doc """
  Parse command-line arguments according to the spec.
  """
  def parse(spec) when is_map(spec),
    do: parse(System.argv, spec, [])

  def parse(args, spec) when is_list(args) and is_map(spec),
    do: parse(args, spec, [])

  def parse(spec, opts) when is_map(spec) and is_list(opts),
    do: parse(System.argv, spec, opts)

  def parse(args, spec, opts)
    when is_list(args) and is_map(spec) and is_list(opts)
  do
    try do
      config =
        Util.compile_config(opts)
        |> Map.put(:name, spec[:name])
      Commando.Parser.parse(args, spec, config)
    catch
      :throw, {:config_error, msg} ->
        raise ArgumentError, message: msg
    end
  end


  @doc """
  Print usage for the spec or one of its subcommands.
  """
  def usage(spec, cmd \\ nil)

  def usage(spec, nil) do
    option_text = format_options(spec[:options], spec[:list_options])
    arg_text = cond do
      spec[:commands] -> "<command> [...]"
      arguments=spec[:arguments] -> format_arguments(arguments)
      true -> ""
    end

    [spec[:prefix], spec[:name], option_text, arg_text]
    |> Enum.reject(&( &1 == "" ))
    |> Util.join(" ")
  end

  def usage(spec, cmd) when is_binary(cmd) do
    if cmd_spec=Util.command_if_exists(spec, cmd) do
      Map.merge(cmd_spec, %{
        prefix: Util.join([spec[:prefix], spec[:name]], " "),
        list_options: spec[:list_options],
      })
      |> usage()
    else
      raise ArgumentError, message: "Unrecognized command: #{cmd}"
    end
  end


  @doc """
  Print help for the spec or one of its subcommands.
  """
  def help(spec, cmd \\ nil)

  def help(%{help: {:full, help}}=spec, nil) do
    lines = String.split(help, "\n")

    opt_text = if opt_indent=get_indent(lines, "{{options}}") do
      format_option_list(spec[:options], opt_indent)
      |> cut_leading_indent(opt_indent)
    end

    cmd_text = if cmd_indent=get_indent(lines, "{{commands}}") do
      format_command_list(spec[:commands], cmd_indent)
      |> cut_leading_indent(cmd_indent)
    end

    arg_text = if arg_indent=get_indent(lines, "{{arguments}}") do
      format_argument_list(spec[:arguments], arg_indent)
      |> cut_leading_indent(arg_indent)
    end

    help = String.replace(help, "{{usage}}", usage(spec))
    if opt_text, do:
      help = String.replace(help, "{{options}}", opt_text)
    if cmd_text, do:
      help = String.replace(help, "{{commands}}", cmd_text)
    if arg_text, do:
      help = String.replace(help, "{{arguments}}", arg_text)
    help
  end

  def help(%{help: help}=spec, nil) do
    options = spec[:options]
    option_text = if not (options in [nil, []]) do
      "Options:\n" <> format_option_list(options, @default_indent)
    end

    cmd_arg_text = cond do
      commands=spec[:commands] ->
        "Commands:\n" <> format_command_list(commands, @default_indent)

      arguments=spec[:arguments] ->
        "Arguments:\n" <> format_argument_list(arguments, @default_indent)

      true -> ""
    end

    lines =
      [help, option_text, cmd_arg_text]
      |> Enum.reject(&( &1 == nil ))
      |> Enum.map(&String.rstrip/1)
      |> Enum.reject(&( &1 == "" ))
      |> Util.join("\n\n")
    if lines != "", do: lines = "\n" <> lines

    """
    Usage:
      #{usage(spec)}
    #{lines}
    """
  end

  def help(%{}=spec, cmd) do
    if cmd_spec=Util.command_if_exists(spec, cmd) do
      Map.merge(cmd_spec, %{
        prefix: Util.join([spec[:prefix], spec[:name]], " "),
        list_options: spec[:list_options],
      })
      |> help()
    else
      raise ArgumentError, message: "Unrecognized command: #{cmd}"
    end
  end


  @doc """
  Format errors returned from the `parse` function.
  """
  def format_error(err), do: Util.format_error(err)

  ###

  defp get_indent(lines, string) do
    line = Enum.find(lines, &String.contains?(&1, string))
    if line do
      byte_size(line) - byte_size(String.lstrip(line))
    end
  end

  defp cut_leading_indent(string, indent),
    do: String.slice(string, indent, byte_size(string))


  defp format_option_list(null, indent) when null in [nil, []],
    do: print_with_indent("", indent)

  defp format_option_list(options, indent),
    do: (Enum.map(options, &format_option_help(&1, indent)) |> Util.join("\n\n"))


  defp format_command_list(null, indent) when null in [nil, []],
    do: print_with_indent("", indent)

  defp format_command_list(commands, indent),
    do: (Enum.map(commands, &format_command_brief(&1, indent)) |> Util.join("\n"))


  defp format_argument_list(null, indent) when null in [nil, []],
    do: print_with_indent("", indent)

  defp format_argument_list(arguments, indent),
    do: (Enum.map(arguments, &format_argument_help(&1, indent)) |> Util.join("\n"))


  defp format_options(null, _) when null in [nil, []], do: ""

  defp format_options(_, nil), do: "[options]"

  defp format_options(options, list_kind),
    do: (Enum.map(options, &(format_option(&1, list_kind) |> wrap_option(&1, list_kind))) |> Util.join(" "))


  defp format_option(opt, :short) do
    if short=opt[:short] do
      name = "-#{Util.name_to_opt(short)}"
      if argname=opt[:argname], do: name = "#{name} <#{argname}>"
      name
    end
  end

  defp format_option(opt, :long) do
    if name=opt[:name] do
      name = "--#{Util.name_to_opt(name)}"
      if argname=opt[:argname], do: name = "#{name}=<#{argname}>"
      name
    end
  end

  defp format_option(opt, :all) do
    [format_option(opt, :short), format_option(opt, :long)]
    |> Enum.reject(&( &1 in [nil, ""] ))
    |> Util.join("|")
  end


  defp format_option_help(opt=%{help: help}, indent) do
    opt_str =
      [format_option(opt, :short), format_option(opt, :long)]
      |> Enum.reject(&( &1 in [nil, ""] ))
      |> Util.join(", ")
    if help == "", do: help = "(no documentation)"

    opt_str = print_with_indent(opt_str, indent)
    help_str = print_with_indent(help, indent + @default_indent)
    Util.join([opt_str, help_str], "\n") |> String.rstrip()
  end


  defp print_with_indent(str, indent_width) do
    indent_str =
      :io_lib.format('~*s', [indent_width, ' '])
      |> String.from_char_data!()

    String.split(str, "\n")
    |> Enum.map(&( indent_str <> &1 ))
    |> Util.join("\n")
  end


  defp wrap_option(null, _, _) when null in [nil, ""], do: ""

  defp wrap_option(formatted, %{short: _, name: _, required: true}, :all),
    do: "{#{formatted}}"

  defp wrap_option(formatted, %{required: false}, _),
    do: "[#{formatted}]"

  defp wrap_option(formatted, _, _), do: formatted


  defp format_command_brief(%{name: name, help: ""}, indent) do
    justified_cmd_str =
      :io_lib.format('~-*s', [10 + @default_indent - indent, name])
      |> String.from_char_data!()
    cmd_str = print_with_indent(justified_cmd_str, indent)
    cmd_str <> "(no documentation)"
  end

  defp format_command_brief(%{name: name, help: help}, indent) do
    justified_cmd_str =
      :io_lib.format('~-*s', [10 + @default_indent - indent, name])
      |> String.from_char_data!()
    cmd_str = print_with_indent(justified_cmd_str, indent)
    cmd_str <> first_sentence(help)
  end


  defp format_arguments([]), do: ""

  defp format_arguments(arguments),
    do: (Enum.map(arguments, &format_argument/1) |> Util.join(" "))


  defp format_argument(%{argname: name, nargs: :inf, required: true}),
    do: "<#{name}> [<#{name}>...]"
  defp format_argument(%{argname: name, nargs: :inf}), do: "[<#{name}>...]"
  defp format_argument(%{argname: name, required: false}), do: "[<#{name}>]"
  defp format_argument(%{argname: name}), do: "<#{name}>"


  defp format_argument_help(%{argname: name, help: ""}, indent) do
    justified_arg_str =
      :io_lib.format('~-*s', [10 + @default_indent - indent, name])
      |> String.from_char_data!()
    arg_str = print_with_indent(justified_arg_str, indent)
    arg_str <> "(no documentation)"
  end

  defp format_argument_help(%{argname: name, help: help}, indent) do
    justified_arg_str =
      :io_lib.format('~-*s', [10 + @default_indent - indent, name])
      |> String.from_char_data!()
    arg_str = print_with_indent(justified_arg_str, indent)
    arg_str <> help
  end


  defp first_sentence(str) do
    case Regex.run(~r/\.(?:  ?[A-Z]|\n|$)/, str, [return: :index]) do
      [{pos, _}] -> elem(String.split_at(str, pos), 0)
      nil        -> str
    end
  end
end
