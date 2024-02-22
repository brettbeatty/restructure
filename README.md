# Restructure

Restructure is a reimagining of Elixir structs. It provides a syntax for building and matching on structs that looks like function calls.

## Usage

When a module uses `Restructure`, `defstruct/1` is extended to allow structs that look more like function calls. These can be made up of ordered fields, named optional fields, or a mix of both. Multiple structs can be defined in a single module.

```elixir
defmodule MyModule do
  use Restructure

  defstruct range(first, last, step: 1)
  defstruct error(message, meta: [], location: nil)
end
```

Creating instances of these structs is as simple as calling the created macro.

```elixir
import MyModule

range(1, 10)
#=> MyModule.range(1, 10, step: 1)
```

These macros can also be used to match on structs.

```elixir
error(_message, location: location) = some_error
```

These structs also implement `Access`, so they can be accessed using the square bracket syntax.

```elixir
range = range(5, 12, step: 2)

range[:last]
#=> 12

range[:step]
#=> 2
```

## Metaprogramming

This exercise provided a lot of metaprogramming practice. The `defstruct/1` macro defines another macro, and keeping track of which values existed at which level took some work. When some values are their own AST it can be hard to remember if you're dealing with code or actual values.

## Future

Some ideas I've had for improving Restructure include the following:

- Guards. It would be some work to implement, but the syntax for these structs would lend itself to defining guards to contrain things when building instances of the structs. That raises the question, though, of multi-clause structs, which would be considerably more complex if I can even decide what that would look like.
- Protocols. One of the great things about Elixir structs is their extensibility through protocols. Since all these "structs" share a common struct, the `Restructure` struct would have to implement any protocols and dispatch to the functional structs, which doesn't seem like it would scale well. Alternatively, each of these function structs could be backed by a unique module struct under the hood. That would take a rework, but it seems like it would better support protocols implementation. That rework would have the advantage of making the dot syntax work and reducing the hidden functions prefixed with RESTRUCTURE. The more I think about this idea the more appealing it is.
- Constructors. I could see a case for transforming values as the struct is created. Maybe this and protocols could be implemented by having a `defstruct/2` that takes a `do` block with alterations to the struct.
