defmodule Serum.Build.FileProcessor.Page do
  @moduledoc false

  require Serum.V2.Result, as: Result
  import Serum.V2.Console, only: [put_msg: 2]
  alias Serum.Build.FileProcessor.Content
  alias Serum.Plugin.Client, as: PluginClient
  alias Serum.Project
  alias Serum.V2
  alias Serum.V2.Error
  alias Serum.V2.Page

  @next_line_key "__serum__next_line__"

  @spec preprocess_pages([V2.File.t()], Project.t()) :: Result.t({[Page.t()], [map()]})
  def preprocess_pages(files, proj) do
    put_msg(:info, "Processing page files...")

    Result.run do
      files <- PluginClient.processing_pages(files)
      pages <- do_preprocess_pages(files, proj)
      sorted_pages = Enum.sort(pages, &(&1.order < &2.order))

      Result.return({sorted_pages, Enum.map(sorted_pages, &Serum.Page.compact/1)})
    end
  end

  @spec do_preprocess_pages([V2.File.t()], Project.t()) :: Result.t([Page.t()])
  defp do_preprocess_pages(files, proj) do
    files
    |> Task.async_stream(&preprocess_page(&1, proj))
    |> Enum.map(&elem(&1, 1))
    |> Result.aggregate("failed to preprocess pages:")
  end

  @spec preprocess_page(V2.File.t(), Project.t()) :: Result.t(Page.t())
  defp preprocess_page(file, proj) do
    import Serum.HeaderParser

    opts = [
      title: :string,
      label: :string,
      group: :string,
      order: :integer,
      template: :string
    ]

    required = [:title]

    Result.run do
      {header, extras, rest, next_line} <- parse_header(file, opts, required)
      header = Map.put(header, :label, header[:label] || header.title)
      page = Serum.Page.new(file, {header, extras}, rest, proj)

      page = %Page{
        page
        | extras: Map.put(page.extras, @next_line_key, next_line)
      }

      Result.return(page)
    end
  end

  @spec process_pages([Page.t()], Project.t()) :: Result.t([Page.t()])
  def process_pages(pages, proj) do
    pages
    |> Task.async_stream(&process_page(&1, proj))
    |> Enum.map(&elem(&1, 1))
    |> Result.aggregate("failed to process pages:")
    |> case do
      {:ok, pages} -> PluginClient.processed_pages(pages)
      {:error, %Error{}} = error -> error
    end
  end

  @spec process_page(Page.t(), Project.t()) :: Result.t(Page.t())
  defp process_page(page, proj) do
    process_opts = [file: page.source, line: page.extras[@next_line_key]]

    case Content.process_content(page.data, page.type, proj, process_opts) do
      {:ok, data} -> Result.return(%Page{page | data: data})
      {:error, %Error{}} = error -> error
    end
  end
end
