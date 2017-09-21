defmodule Arc.Definition.Storage do
  defmacro __using__(_) do
    quote do
      # Access control permission for AWS
      @acl :private
      @async true

      @doc """
      Returns the name of the file with the extension stripped by default
      """
      def filename(_, {file, _}), do: Path.basename(file.file_name, Path.extname(file.file_name))

      @doc """
      Returns "uploads" by default
      """
      def storage_dir(_, _), do: "uploads"
      
      @doc """
      Returns true by default
      """
      def validate(_), do: true

      @doc """
      Returns `default_url(version)` by default
      """
      def default_url(version, _), do: default_url(version)

      @doc """
      Returns nil by default
      """
      def default_url(_), do: nil

      @doc """
      Tries to get :storage configuration or else returns the Storage.S3 module by default
      """
      def __storage, do: Application.get_env(:arc, :storage, Arc.Storage.S3)

      @doc """
      Allow the user to define his own functions in place of the above
      placeholder functions.
      """
      defoverridable [storage_dir: 2, filename: 2, validate: 1, default_url: 1, default_url: 2, __storage: 0]

      # Invoke Arc.Definition.Storage.__before_compile__/1
      # before the module is compiled.
      @before_compile Arc.Definition.Storage
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Returns :private by default
      """
      def acl(_, _), do: @acl

      @doc """
      Returns an empty list by default
      """
      def s3_object_headers(_, _), do: []

      @doc """
      Returns true by default
      """
      def async, do: @async
    end
  end
end
