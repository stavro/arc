defmodule Arc.Definition.Storage do
  defmacro __using__(_) do
    quote do
      @acl :private
      @async true

      def filename(_, {file, _}), do: Path.basename(file.file_name, Path.extname(file.file_name))
      def storage_dir(_, _), do: "priv/uploads"
      def request_dir(version, {file, scope}), do: storage_dir(version, {file, scope})
      def validate(_), do: true
      def default_url(version, _), do: default_url(version)
      def default_url(_), do: nil
      def __storage, do: Application.get_env(:arc, :storage, Arc.Storage.S3)

      defoverridable [request_dir: 2, storage_dir: 2, filename: 2, validate: 1, default_url: 1, default_url: 2, __storage: 0]

      @before_compile Arc.Definition.Storage
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def acl(_, _), do: @acl
      def s3_object_headers(_, _), do: []
      def async, do: @async
    end
  end
end
