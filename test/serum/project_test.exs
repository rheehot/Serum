defmodule Serum.ProjecTest do
  use Serum.Case, async: true
  import ExUnit.CaptureIO
  alias Serum.Project
  alias Serum.V2.Console

  setup_all do
    {:ok, io_opts} = Console.config()

    Console.config(mute_err: false)
    on_exit(fn -> Console.config(Keyword.new(io_opts)) end)
  end

  describe "fallback string format" do
    test "default" do
      proj = Project.new(%{})

      assert proj.date_format === Project.default_date_format()
      assert proj.list_title_tag === Project.default_list_title_tag()
    end

    test "good" do
      date_format = "{WDfull}, {D} {Mshort} {YYYY}"
      list_title_tag = "Posts about ~s"
      map = %{date_format: date_format, list_title_tag: list_title_tag}
      warn = capture_io(:stderr, fn -> send(self(), Project.new(map)) end)

      assert warn === ""

      receive do
        %Project{} = proj ->
          assert proj.date_format === date_format
          assert proj.list_title_tag === list_title_tag
      after
        1000 -> flunk("no message from capture_io after 1 second")
      end
    end

    test "bad date format" do
      date_format = "{WDfull, {D} {Mshort} {YYYY}"
      list_title_tag = "Posts about ~s"
      map = %{date_format: date_format, list_title_tag: list_title_tag}
      warn = capture_io(:stderr, fn -> send(self(), Project.new(map)) end)

      assert String.contains?(warn, "Invalid")

      receive do
        %Project{} = proj ->
          assert proj.date_format === Project.default_date_format()
          assert proj.list_title_tag === list_title_tag
      after
        1000 -> flunk("no message from capture_io after 1 second")
      end
    end

    test "bad list title format" do
      date_format = "{WDfull}, {D} {Mshort} {YYYY}"
      list_title_tag = "Posts about something"
      map = %{date_format: date_format, list_title_tag: list_title_tag}
      warn = capture_io(:stderr, fn -> send(self(), Project.new(map)) end)

      assert String.contains?(warn, "Invalid")

      receive do
        %Project{} = proj ->
          assert proj.date_format === date_format
          assert proj.list_title_tag === Project.default_list_title_tag()
      after
        1000 -> flunk("no message from capture_io after 1 second")
      end
    end

    test "both the date format and the list title format are bad" do
      date_format = "{WDfull, {D} {Mshort} {YYYY}"
      list_title_tag = "Posts about something"
      map = %{date_format: date_format, list_title_tag: list_title_tag}
      warn = capture_io(:stderr, fn -> send(self(), Project.new(map)) end)

      assert String.contains?(warn, "Invalid")

      receive do
        %Project{} = proj ->
          assert proj.date_format === Project.default_date_format()
          assert proj.list_title_tag === Project.default_list_title_tag()
      after
        1000 -> flunk("no message from capture_io after 1 second")
      end
    end
  end
end
