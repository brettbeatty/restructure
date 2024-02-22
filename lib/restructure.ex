defmodule Restructure do
  defstruct [:data, :module, :name]

  defmacro defstruct(fields)

  defmacro defstruct({name, _meta, fields}) when is_atom(name) and is_list(fields) do
    defstruct(__CALLER__, name, fields)
  end

  # handle 0-arity without parens
  defmacro defstruct({name, _meta, context}) when is_atom(name) and is_atom(context) do
    defstruct(__CALLER__, name, [])
  end

  defmacro defstruct(fields) do
    quote do
      Kernel.defstruct(unquote(fields))
    end
  end

  defp defstruct(env, name, fields) do
    named_fields_var = check_fields(fields)
    macro = build_macro(name, fields, named_fields_var)
    constructor = build_constructor(env, name, fields, named_fields_var)
    fetcher = build_fetcher(env, name, fields)
    named_field_tag = build_named_fields_tag(name, named_fields_var)

    quote do
      unquote(macro)
      unquote(constructor)
      unquote_splicing(fetcher)
      unquote(named_field_tag)
    end
  end

  defp check_fields(fields)

  defp check_fields([{name, _meta, context} | fields]) when is_atom(name) and is_atom(context) do
    check_fields(fields)
  end

  defp check_fields([named_fields]) when is_list(named_fields) do
    if Keyword.keyword?(named_fields) do
      Macro.unique_var(:named_fields, __MODULE__)
    else
      raise "named fields must be a keyword list"
    end
  end

  defp check_fields([]) do
    nil
  end

  defp build_macro(name, fields, named_fields_var) do
    macro_args = build_macro_args(fields, named_fields_var)
    constructor_args = build_constructor_args(fields, named_fields_var)
    named_fields? = not is_nil(named_fields_var)

    quote do
      defmacro unquote(name)(unquote_splicing(macro_args)) do
        Restructure._build_structure(
          __CALLER__,
          __MODULE__,
          unquote(name),
          unquote(constructor_args),
          unquote(named_fields?)
        )
      end
    end
  end

  defp build_macro_args(fields, named_fields_var) do
    Enum.map(fields, fn
      ordered_field when is_tuple(ordered_field) ->
        ordered_field

      named_fields when is_list(named_fields) ->
        quote do
          unquote(named_fields_var) \\ []
        end
    end)
  end

  def _build_structure(env, module, name, fields, named_fields?)

  def _build_structure(env, module, name, fields, _named_fields?)
      when env.context in [nil, :guard] do
    quote do
      unquote(module).unquote(:"RESTRUCTURE-#{name}")(unquote_splicing(fields))
    end
  end

  def _build_structure(env, module, name, fields, _named_fields? = false)
      when env.context == :match do
    build_wrapper(module, name, fields)
  end

  def _build_structure(env, module, name, fields, _named_fields? = true)
      when env.context == :match do
    build_wrapper(module, name, build_named_field_match(fields))
  end

  defp build_named_field_match(fields) do
    List.update_at(fields, -1, fn
      var when is_tuple(var) ->
        var

      pairs when is_list(pairs) ->
        if Keyword.keyword?(pairs) do
          {:%{}, [], pairs}
        else
          pairs
        end
    end)
  end

  defp build_constructor(env, name, fields, named_fields_var) do
    args = build_constructor_args(fields, named_fields_var)
    data = build_data(fields, named_fields_var)

    quote do
      def unquote(:"RESTRUCTURE-#{name}")(unquote_splicing(args)) do
        unquote(build_wrapper(env.module, name, data))
      end
    end
  end

  defp build_constructor_args(fields, named_fields_var)

  defp build_constructor_args(fields, named_fields_var) when is_tuple(named_fields_var) do
    List.replace_at(fields, -1, named_fields_var)
  end

  defp build_constructor_args(fields, nil) do
    fields
  end

  defp build_data(fields, named_fields_var)

  defp build_data(fields, named_fields_var) when is_tuple(named_fields_var) do
    List.update_at(fields, -1, fn named_fields ->
      named_data =
        Enum.map(named_fields, fn {key, default} ->
          value =
            quote do
              Keyword.get(unquote(named_fields_var), unquote(key), unquote(default))
            end

          {key, value}
        end)

      {:%{}, [], named_data}
    end)
  end

  defp build_data(fields, nil) do
    fields
  end

  defp build_fetcher(env, name, fields) do
    fetcher_name = :"RESTRUCTURE-#{name}-FETCH"
    module = env.module
    underscore = Macro.var(:_, __MODULE__)
    underscores = Enum.map(fields, fn _ -> underscore end)

    builder = &build_fetcher_clause(module, name, fetcher_name, &1, &2, &3)

    build_fetcher_clauses(fields, underscores, [], builder)
  end

  defp build_fetcher_clause(module, name, fetcher_name, fields, key, value) do
    wrapper = build_wrapper(module, name, fields)

    quote do
      def unquote(fetcher_name)(unquote(wrapper), unquote(key)) do
        unquote(value)
      end
    end
  end

  defp build_fetcher_clauses(fields, next_underscores, prev_underscores, builder)

  defp build_fetcher_clauses([field | fields], [underscore | next], prev, builder)
       when tuple_size(field) == 3 do
    {field_name, _meta, _context} = field
    clause = builder.(prev ++ [field | next], field_name, {:ok, field})

    [clause | build_fetcher_clauses(fields, next, [underscore | prev], builder)]
  end

  defp build_fetcher_clauses([named_fields], [underscore], prev, builder)
       when is_list(named_fields) do
    clauses = build_named_fetcher_clauses(named_fields, prev, builder)
    clauses ++ build_fetcher_clauses([], [], [underscore | prev], builder)
  end

  defp build_fetcher_clauses([], [], prev, builder) do
    [builder.(prev, Macro.var(:_, __MODULE__), :error)]
  end

  defp build_named_fetcher_clauses(named_fields, ordered_fields, builder)

  defp build_named_fetcher_clauses([{key, _default} | named_fields], underscores, builder) do
    var = Macro.var(key, __MODULE__)

    match =
      quote do
        %{unquote(key) => unquote(var)}
      end

    clause = builder.(underscores ++ [match], key, {:ok, var})

    [clause | build_named_fetcher_clauses(named_fields, underscores, builder)]
  end

  defp build_named_fetcher_clauses([], _underscores, _builder) do
    []
  end

  def fetch(struct, key) do
    %Restructure{module: module, name: name} = struct
    apply(module, :"RESTRUCTURE-#{name}-FETCH", [struct, key])
  end

  defp build_wrapper(module, name, fields) do
    quote do
      %Restructure{
        data: {unquote_splicing(fields)},
        module: unquote(module),
        name: unquote(name)
      }
    end
  end

  defp build_named_fields_tag(name, named_fields_var) do
    named_fields? = not is_nil(named_fields_var)

    quote do
      def unquote(:"RESTRUCTURE-#{name}-NAMED-FIELDS?")() do
        unquote(named_fields?)
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      import Kernel, except: [defstruct: 1]
      import Restructure, only: [defstruct: 1]
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(struct, opts) do
      %Restructure{data: data, module: module, name: name} = struct

      left = "#{Macro.inspect_atom(:literal, module)}.#{Macro.inspect_atom(:remote_call, name)}("
      contents = data |> Tuple.to_list() |> inspect_data(module, name, opts)
      right = ")"

      container_doc(left, contents, right, opts, &identity/2)
    end

    defp inspect_data(data, module, name, opts) do
      named_fields? = apply(module, :"RESTRUCTURE-#{name}-NAMED-FIELDS?", [])
      inspect_ordered_data(data, named_fields?, opts)
    end

    defp inspect_ordered_data(data, named_fields?, opts)

    defp inspect_ordered_data([named_data], _named_fields? = true, opts) do
      named_data
      |> Enum.sort()
      |> inspect_named_data(opts)
    end

    defp inspect_ordered_data([datum | ordered_data], named_fields?, opts) do
      [to_doc(datum, opts) | inspect_ordered_data(ordered_data, named_fields?, opts)]
    end

    defp inspect_ordered_data([], _named_fields?, _opts) do
      []
    end

    defp inspect_named_data(data, opts)

    defp inspect_named_data([datum | data], opts) do
      [Inspect.List.keyword(datum, opts) | inspect_named_data(data, opts)]
    end

    defp inspect_named_data([], _opts) do
      []
    end

    defp identity(doc, _opts) do
      doc
    end
  end
end
