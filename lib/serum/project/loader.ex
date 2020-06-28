defmodule Serum.Project.Loader do
  @moduledoc false

  _moduledocp = "A module for loading Serum project definition files."

  require Serum.V2.Result, as: Result
  alias Serum.GlobalBindings
  alias Serum.Project
  alias Serum.Project.ElixirValidator
  alias Serum.V2
  alias Serum.V2.Error

  @doc """
  Detects and loads Serum project definition file from the source directory.
  """
  @spec load(binary(), binary()) :: Result.t(Project.t())
  def load(src, dest) do
    case do_load(src) do
      {:ok, %Project{} = proj} ->
        GlobalBindings.put(:site, %{
          name: proj.site_name,
          description: proj.site_description,
          author: proj.author,
          author_email: proj.author_email,
          server_root: proj.server_root,
          base_url: proj.base_url
        })

        Result.return(%Project{proj | src: src, dest: dest})

      {:error, %Error{}} = error ->
        error
    end
  end

  @spec do_load(binary()) :: Result.t(Project.t())
  defp do_load(src) do
    exs_file = %V2.File{src: Path.join(src, "serum.exs")}

    Result.run do
      file <- V2.File.read(exs_file)
      value <- eval_file(file)
      ElixirValidator.validate(value)

      value |> Project.new() |> Result.return()
    end
  end

  @spec eval_file(V2.File.t()) :: Result.t(term())
  defp eval_file(file) do
    file.in_data
    |> Code.eval_string([], file: file.src)
    |> elem(0)
    |> Result.return()
  rescue
    e in [CompileError, SyntaxError, TokenMissingError] ->
      Result.fail(Exception: [e, __STACKTRACE__], file: file, line: e.line)

    e ->
      Result.fail(Exception: [e, __STACKTRACE__], file: file)
  end
end
