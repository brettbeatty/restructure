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
    macro = build_macro(name, fields)
    constructor = build_constructor(env, name, fields)
    fetcher = build_fetcher(env, name, fields)

    quote do
      unquote(macro)
      unquote(constructor)
      unquote_splicing(fetcher)
    end
  end

  defp build_macro(name, fields) do
    quote do
      defmacro unquote(name)(unquote_splicing(fields)) do
        Restructure._build_structure(__CALLER__, __MODULE__, unquote(name), unquote(fields))
      end
    end
  end

  defp build_constructor(env, name, fields) do
    quote do
      def unquote(:"RESTRUCTURE-#{name}")(unquote_splicing(fields)) do
        unquote(build_wrapper(env.module, name, fields))
      end
    end
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

  defp build_fetcher_clauses([field | fields], [underscore | next], prev, builder) do
    {field_name, _meta, _context} = field
    clause = builder.(prev ++ [field | next], field_name, {:ok, field})

    [clause | build_fetcher_clauses(fields, next, [underscore | prev], builder)]
  end

  defp build_fetcher_clauses([], [], prev, builder) do
    [builder.(prev, Macro.var(:_, __MODULE__), :error)]
  end

  def fetch(struct, key) do
    %Restructure{module: module, name: name} = struct
    apply(module, :"RESTRUCTURE-#{name}-FETCH", [struct, key])
  end

  def _build_structure(env, module, name, fields)

  def _build_structure(env, module, name, fields) when env.context in [nil, :guard] do
    quote do
      unquote(module).unquote(:"RESTRUCTURE-#{name}")(unquote_splicing(fields))
    end
  end

  def _build_structure(env, module, name, fields) when env.context == :match do
    build_wrapper(module, name, fields)
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
      right = ")"

      container_doc(left, Tuple.to_list(data), right, opts, &to_doc/2)
    end
  end
end
