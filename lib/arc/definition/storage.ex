defmodule Arc.Definition.Storage do
  defmacro __using__(_) do
    quote do
      @acl :private

      def filename(_, {file, _}), do: Path.basename(file.file_name, Path.extname(file.file_name))
      def storage_dir(_, _), do: "uploads"
      def validate(_), do: true
      def default_url(version, _), do: default_url(version)
      def default_url(_), do: nil
      def __storage, do: Application.get_env(:arc, :storage) || Arc.Storage.S3

      defoverridable [storage_dir: 2, filename: 2, validate: 1, default_url: 1, default_url: 2, __storage: 0]

      @before_compile Arc.Definition.Storage
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def acl(_, _), do: @acl
    end
  end
end
