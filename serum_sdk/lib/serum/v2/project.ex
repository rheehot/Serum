defmodule Serum.V2.Project do
  @moduledoc """
  A struct containing a project configuration.

  ## Fields

  - `source_dir` - directory of the project root. This will be automatically
    filled by Serum after the project has been successfuly loaded. Do not set
    or modify this value on your own.
  - `dest_dir` - path to the output directory. This will be automatically filled
    by Serum after the project has been successfully loaded. Do not set or
    modify this value on your own.
  - `title` - title of the website.
  - `description` - description (or subtitle) of the website.
  - `base_url` - absolute path of the root of the website on the Internet. The
    value must begin with either `http://` or `https://`.
  - `authors` - a map which contains information about authors of website
    contents. Keys must be a string, and each value can be arbitrary key-value
    container which contains user-defined information for each author.
  - `blogs` - a list of `Serum.V2.Project.BlogConfiguration` structs. This can
    be an empty list if the website does not need any blogging capability. This
    can contain more than one `Serum.V2.Project.BlogConfiguration` if the
    website should have multiple separate blogs within it.
  - `theme` - configures the theme module and its arguments. Defaults to `nil`,
    which means no theme. Read the documentation for the `Serum.V2.Theme` module
    for more information about how to apply a theme to your website.
  - `plugins` - a list of plugins to use when building the project. Read the
    documentation for the `Serum.V2.Plugin` module for more information about
    how to use Serum plugins for your project.
  """

  alias Serum.V2.Plugin
  alias Serum.V2.Project.BlogConfiguration
  alias Serum.V2.Theme

  @type t :: %__MODULE__{
          source_dir: binary(),
          dest_dir: binary(),
          title: binary(),
          description: binary(),
          base_url: URI.t(),
          authors: authors(),
          blogs: BlogConfiguration.t() | false,
          theme: Theme.spec() | nil,
          plugins: [Plugin.spec()]
        }

  @type authors() :: %{optional(binary()) => Access.t()}

  defstruct source_dir: "",
            dest_dir: "",
            title: "",
            description: "",
            base_url: %URI{},
            authors: %{},
            blogs: %BlogConfiguration{},
            theme: nil,
            plugins: []
end
