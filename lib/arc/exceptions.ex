defmodule Arc.MissingExecutableError do
  defexception [:message]

  def exception(opts) do
    message = Keyword.fetch!(opts, :message)

    msg = """
    Cannot locate executable: #{message}
    """

    %__MODULE__{message: msg}
  end
end
