defmodule Arc.Definition.Storage do
  defmacro __using__(_) do
    quote do
      # Access control permission for AWS
      @acl :private
      @async true

      @doc """
      Function to replace original filename

      By default, this function returns the name of the uploaded file
      sans the extension.
      """
      def filename(_version, {file, _scope}), 
      do: Path.basename(file.file_name, Path.extname(file.file_name))

      @doc """
      Storage directory to upload the file to

      Be default, this is just "uploads" but you may want to name the directory
      based on scope and version.
      """
      def storage_dir(_version, {_file, _scope}), 
      do: "uploads"
      
      @doc """
      Validate extension of files

      By default, there is no validation. For better security, it is recommended
      that you define a custom validation function that whitelists certain 
      extensions.
      """
      def validate({_file, _scope}), 
      do: true

      @doc """
      Function to return placeholder images

      By default, there is no placeholder images but 
      """
      def default_url(version, _), 
      do: default_url(version)

      @doc """
      Returns nil by default
      """
      def default_url(_), 
      do: nil

      @doc """
      Tries to get :storage configuration or else returns the Storage.S3 module by default
      """
      def __storage, 
      do: Application.get_env(:arc, :storage, Arc.Storage.S3)

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
