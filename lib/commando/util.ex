defmodule Commando.Util do
  @moduledoc false

  def name_to_opt(name), do: String.replace(name, "_", "-")
end
