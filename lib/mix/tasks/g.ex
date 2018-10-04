defmodule Mix.Tasks.Arc do
  defmodule G do
    use Mix.Task
    import Mix.Generator
    import Macro, only: [camelize: 1, underscore: 1]

    @shortdoc "For Arc definition generation code"

    @moduledoc """
    A task for generating arc uploader modules.

    If generating an uploader in a Phoenix project, your a uploader will be generated in
    lib/[APP_NAME]_web/uploaders/

    ## Example

        mix arc.g avatar # creates  lib/[APP_NAME]_web/uploaders/avatar.ex


    If not generating an uploader in a Phoenix project, then you must pass the path to where the
    uploader should be generated.

    ## Example

        mix arc.g avatar  uploaders/avatar.ex # creates uploaders/avatar.ex
    """

    def run([model_name]) do
      app_name = Mix.Project.config[:app]
      if (File.exists?("lib/#{app_name}_web/")) do
        project_module_name = camelize(to_string(app_name))
        generate_phx_uploader_file(model_name, project_module_name)
      else
        raise "path must be passed when generating an uploader."
      end
    end

    def run([model_name, path]) do
      app_name = Mix.Project.config[:app]
      project_module_name = camelize(to_string(app_name))
      generate_uploader_file(model_name, project_module_name, path)
    end

    def run(_) do
      IO.puts "Incorrect syntax. Please try mix arc.g <model_name>"
    end

    defp generate_uploader_file(model_name, project_module_name, path) do
      model_destination = Path.join(System.cwd(), "#{path}/#{underscore(model_name)}.ex")
      create_uploader(model_name, project_module_name, model_destination)
    end

    defp generate_phx_uploader_file(model_name, project_module_name) do
      app_name = Mix.Project.config[:app]
      model_destination = Path.join(System.cwd(), "/lib/#{app_name}_web/uploaders/#{underscore(model_name)}.ex")
      create_uploader(model_name, project_module_name, model_destination)
    end

    defp create_uploader(model_name, project_module_name, model_destination) do
      create_file model_destination, uploader_template(
          model_name: model_name,
          uploader_model_name: Module.concat(project_module_name, camelize(model_name))
      )
    end

    embed_template :uploader, """
    defmodule <%= inspect @uploader_model_name %> do
      use Arc.Definition

      # Include ecto support (requires package arc_ecto installed):
      # use Arc.Ecto.Definition

      @versions [:original]

      # To add a thumbnail version:
      # @versions [:original, :thumb]

      # Override the bucket on a per definition basis:
      # def bucket do
      #   :custom_bucket_name
      # end

      # Whitelist file extensions:
      # def validate({file, _}) do
      #   ~w(.jpg .jpeg .gif .png) |> Enum.member?(Path.extname(file.file_name))
      # end

      # Define a thumbnail transformation:
      # def transform(:thumb, _) do
      #   {:convert, "-strip -thumbnail 250x250^ -gravity center -extent 250x250 -format png", :png}
      # end

      # Override the persisted filenames:
      # def filename(version, _) do
      #   version
      # end

      # Override the storage directory:
      # def storage_dir(version, {file, scope}) do
      #   "uploads/user/avatars/\#{scope.id}"
      # end

      # Provide a default URL if there hasn't been a file uploaded
      # def default_url(version, scope) do
      #   "/images/avatars/default_\#{version}.png"
      # end

      # Specify custom headers for s3 objects
      # Available options are [:cache_control, :content_disposition,
      #    :content_encoding, :content_length, :content_type,
      #    :expect, :expires, :storage_class, :website_redirect_location]
      #
      # def s3_object_headers(version, {file, scope}) do
      #   [content_type: MIME.from_path(file.file_name)]
      # end
    end
    """

  end
end
