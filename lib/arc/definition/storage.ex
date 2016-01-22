defmodule Arc.Definition.Storage do
  defmacro __using__(_) do
    quote do
      @acl :private

      def filename(_, {file, _}), do: Path.basename(file.file_name, Path.extname(file.file_name))
      def storage_dir(_, _), do: "uploads"
      def validate(_), do: true
      def default_url(version, _), do: default_url(version)
      def default_url(_), do: nil
      def options(_, _), do: %{content_disposition: nil,
                               content_encoding: nil,
                               content_length: nil,
                               content_type: nil,
                               expect: nil,
                               storage_class: "STANDARD",
                               website_redirect_location: nil,
                               encryption: nil,
                               meta: nil}
      def __storage, do: Arc.Storage.S3

      defoverridable [storage_dir: 2, filename: 2, options: 2, validate: 1, default_url: 1, default_url: 2, __storage: 0]

      @before_compile Arc.Definition.Storage
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def acl(_, _), do: @acl
    end
  end
end
