defmodule Mix.Tasks.Arc do
  defmodule G do
    use Mix.Task
    import Mix.Generator
    import Mix.Utils, only: [camelize: 1, underscore: 1]

    @shortdoc "For Arc definition generation code"

    @moduledoc """
      A task for generating arc uploader modules.
    """

    def run([model_name]) do
      app_name = Mix.Project.config[:app]
      project_module_name = camelize(to_string(app_name))
      model_destination = Path.join(System.cwd(), "/web/uploaders/#{underscore(model_name)}.ex")
      generate_uploader_file(model_name, project_module_name)
    end

    def run(_) do
      IO.puts "Incorrect syntax. Please try mix arc.g <model_name>"
    end

    defp generate_uploader_file(model_name, project_module_name) do
      model_destination = Path.join(System.cwd(), "/web/uploaders/#{underscore(model_name)}.ex")
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

      # Whitelist file extensions:
      # def validate({file, _}) do
      #   ~w(.jpg .jpeg .gif .png) |> Enum.member?(Path.extname(file.file_name))
      # end

      # Define a thumbnail transformation:
      # def transform(:thumb, _) do
      #   {:convert, "-strip -thumbnail 250x250^ -gravity center -extent 250x250 -format png"}
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

      # Fine tune how your file is stored
      # Elements with value nil will get ignored
      # def options(version, {file, scope}) do
      #   %{content_disposition: nil,
      #     content_encoding: nil,
      #     content_length: nil,
      #     content_type: nil,
      #     expect: nil,
      #     storage_class: "STANDARD", # maybe REDUCED_REDUNDANCY?
      #     website_redirect_location: nil,
      #     encryption: nil,
      #     meta: nil} # [{"Your-Key", "Your-Value"}]
      # end
    end
    """

  end
end
