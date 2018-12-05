defmodule Arc.MissingExecutableError do
  defexception [:message]

  def exception(opts) do
    message = Keyword.fetch!(opts, :message)

    msg = case unix_operating_system?() do
      true ->
        "Please look into installing imagemagick first."
      false ->
        ""
    end

    msg = msg <> " \n Cannot locate executable: #{message}"

    %__MODULE__{message: msg}
  end

  defp unix_operating_system?() do
    {:unix, :darwin} == :os.type()
  end
end
