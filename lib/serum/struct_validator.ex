defmodule Serum.StructValidator do
  @moduledoc false

  @type result() :: :ok | {:invalid, binary()} | {:invalid, [binary()]}

  @spec __using__(term()) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: [define_validator: 1]
    end
  end

  @spec define_validator(keyword()) :: Macro.t()
  defmacro define_validator(do: do_block) do
    exprs =
      case do_block do
        {:__block__, _, exprs} when is_list(exprs) -> exprs
        expr -> [expr]
      end

    def_validate_expr =
      quote unquote: false do
        @spec validate(term()) :: unquote(used_module).result()
        def validate(term) do
          unquote(used_module)._validate(
            term,
            __MODULE__,
            unquote(all_keys),
            unquote(required_keys)
          )
        end
      end

    def_validate_field_expr =
      quote unquote: false do
        def _validate_field(unquote(name), var!(value)) do
          if unquote(check_expr) do
            :ok
          else
            {:fail, unquote(check_str)}
          end
        end
      end

    quote do
      import unquote(__MODULE__), only: [key: 2]

      used_module = unquote(__MODULE__)
      key_specs = unquote(exprs)
      all_keys = key_specs |> Keyword.keys() |> MapSet.new() |> Macro.escape()

      required_keys =
        key_specs
        |> Enum.filter(&elem(&1, 1)[:required])
        |> Keyword.keys()
        |> MapSet.new()
        |> Macro.escape()

      unquote(def_validate_expr)

      @spec _validate_field(atom(), term()) :: :ok | {:fail, binary()}
      def _validate_field(key, value)

      Enum.map(key_specs, fn {name, opts} ->
        rules = opts[:rules] || []

        check_expr =
          rules
          |> Enum.map(fn {func, args} ->
            escaped_args = Enum.map(args, &Macro.escape/1)

            quote(do: unquote(func)(var!(value), unquote_splicing(escaped_args)))
          end)
          |> Enum.reduce(&quote(do: unquote(&2) and unquote(&1)))

        check_str =
          rules
          |> Enum.map(fn {func, args} ->
            quote(do: unquote(func)(value, unquote_splicing(args)))
          end)
          |> Enum.reduce(&quote(do: unquote(&2) and unquote(&1)))
          |> Macro.to_string()

        unquote(def_validate_field_expr)
      end)
    end
  end

  @spec key(atom(), keyword()) :: Macro.t()
  defmacro key(name, opts), do: quote(do: {unquote(name), unquote(opts)})

  @doc false
  @spec _validate(term(), module(), term(), term()) :: result()
  def _validate(value, module, all_keys, required_keys)

  def _validate(%{} = map, module, all_keys, required_keys) do
    keys = map |> Map.keys() |> MapSet.new()

    with {:missing, []} <- check_missing_keys(keys, required_keys),
         {:extra, []} <- check_extra_keys(keys, all_keys),
         :ok <- check_constraints(map, module) do
      :ok
    else
      {:missing, [x]} ->
        {:invalid, "missing required property: #{x}"}

      {:missing, xs} ->
        props_str = Enum.join(xs, ", ")

        {:invalid, "missing required properties: #{props_str}"}

      {:extra, [x]} ->
        {:invalid, "unknown property: #{x}"}

      {:extra, xs} ->
        props_str = Enum.join(xs, ", ")

        {:invalid, "unknown properties: #{props_str}"}

      {:error, messages} ->
        {:invalid, messages}
    end
  end

  def _validate(term, _module, _all_keys, _required_keys) do
    {:invalid, "expected a map, got: #{inspect(term)}"}
  end

  @spec check_missing_keys(term(), term()) :: {:missing, [atom()]}
  defp check_missing_keys(keys, required_keys) do
    missing =
      required_keys
      |> MapSet.difference(keys)
      |> MapSet.to_list()

    {:missing, missing}
  end

  @spec check_extra_keys(term(), term()) :: {:extra, [atom()]}
  defp check_extra_keys(keys, all_keys) do
    extra =
      keys
      |> MapSet.difference(all_keys)
      |> MapSet.to_list()

    {:extra, extra}
  end

  @spec check_constraints(map(), module()) :: :ok | {:error, [binary()]}
  defp check_constraints(map, module) do
    map
    |> Enum.map(fn {k, v} -> {k, module._validate_field(k, v)} end)
    |> Enum.filter(&(elem(&1, 1) != :ok))
    |> case do
      [] ->
        :ok

      errors ->
        messages =
          Enum.map(errors, fn {k, {:fail, s}} ->
            [
              "the property ",
              [:bright, :yellow, to_string(k), :reset],
              " violates the constraint ",
              [:bright, :yellow, s, :reset]
            ]
            |> IO.ANSI.format()
            |> IO.iodata_to_binary()
          end)

        {:error, messages}
    end
  end
end
