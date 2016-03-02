defmodule Arc.ConvertError do
  defexception [:message]

  def exception(opts) do
    message = Keyword.fetch!(opts, :message)
    exit_code = Keyword.fetch!(opts, :exit_code)

    msg = """
    Convert exited unsuccessfully with exit code #{exit_code}:
    #{message}
    """

    %__MODULE__{message: msg}
  end
end

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
