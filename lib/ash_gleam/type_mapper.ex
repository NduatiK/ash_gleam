# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.TypeMapper do
  @moduledoc false

  @scalar_types [:string, :integer, :boolean, :float, :decimal, :uuid, :term]
  @type_constraints [:one_of, :items]
  @scalar_type_modules %{
    Ash.Type.String => :string,
    Ash.Type.Integer => :integer,
    Ash.Type.Boolean => :boolean,
    Ash.Type.Float => :float,
    Ash.Type.Decimal => :decimal,
    Ash.Type.UUID => :uuid,
    Ash.Type.Term => :term
  }

  @spec supported?(term(), Keyword.t()) :: boolean()
  def supported?(type, constraints \\ []) do
    case normalize(type, constraints) do
      {:ok, {:scalar, _}} -> true
      {:ok, {:constrained_atom, _}} -> true
      {:ok, {:reusable_union, _, variants}} -> Enum.all?(variants, &supported_union_variant?/1)
      {:ok, {:array, inner}} -> supported?(inner)
      {:ok, {:resource, module}} -> ash_gleam_resource?(module)
      :error -> false
    end
  end

  @spec normalize(term(), Keyword.t()) :: {:ok, term()} | :error

  # Pass-through for already-normalized forms produced by recursive normalize calls.
  def normalize({:scalar, _} = normalized, _constraints), do: {:ok, normalized}
  def normalize({:constrained_atom, _} = normalized, _constraints), do: {:ok, normalized}
  def normalize({:reusable_union, _, _} = normalized, _constraints), do: {:ok, normalized}
  def normalize({:resource, _} = normalized, _constraints), do: {:ok, normalized}

  def normalize({:array, inner}, constraints) do
    item_constraints =
      constraints
      |> Keyword.get(:items, [])
      |> List.wrap()

    with {:ok, inner} <- normalize(inner, item_constraints) do
      {:ok, {:array, inner}}
    end
  end

  def normalize(type, _constraints) when type in @scalar_types, do: {:ok, {:scalar, type}}

  def normalize(atom, constraints) when atom in [:atom, Ash.Type.Atom] do
    case Keyword.take(constraints, @type_constraints) do
      [one_of: values] when is_list(values) and values != [] ->
        {:ok, {:constrained_atom, values}}

      _ ->
        :error
    end
  end

  def normalize(type, constraints) when is_atom(type) do
    cond do
      type in @scalar_types ->
        {:ok, {:scalar, type}}

      mapped = @scalar_type_modules[type] ->
        {:ok, {:scalar, mapped}}

      type == Ash.Type.Struct and ash_gleam_resource?(Keyword.get(constraints, :instance_of)) ->
        {:ok, {:resource, Keyword.fetch!(constraints, :instance_of)}}

      AshGleam.ReusableType.union?(type) ->
        case AshGleam.ReusableType.definition(type) do
          {:ok, %{variants: variants}} -> {:ok, {:reusable_union, type, variants}}
          :error -> :error
        end

      ash_gleam_resource?(type) ->
        {:ok, {:resource, type}}

      true ->
        normalize_atom_type(type, constraints)
    end
  end

  def normalize(_, _constraints), do: :error

  @spec ash_type(term(), Keyword.t()) :: {:ok, {term(), Keyword.t()}} | :error
  def ash_type(type, constraints \\ []) do
    case normalize(type, constraints) do
      {:ok, {:scalar, scalar}} ->
        {:ok, {scalar, []}}

      {:ok, {:constrained_atom, values}} ->
        {:ok, {:atom, one_of: values}}

      {:ok, {:reusable_union, module, _variants}} ->
        {:ok, {module, []}}

      {:ok, {:array, inner}} ->
        item_constraints =
          constraints
          |> Keyword.get(:items, [])
          |> List.wrap()

        with {:ok, {inner_type, inner_constraints}} <- ash_type(inner, item_constraints) do
          array_constraints =
            case inner_constraints do
              [] -> []
              _ -> [items: inner_constraints]
            end

          {:ok, {{:array, inner_type}, array_constraints}}
        end

      {:ok, {:resource, module}} ->
        {:ok, {:struct, [instance_of: module]}}

      :error ->
        :error
    end
  end

  @spec gleam_type(term(), Keyword.t()) :: {:ok, String.t()} | :error
  def gleam_type(type, opts \\ [])

  def gleam_type(type, opts) do
    nullable? = Keyword.get(opts, :allow_nil?, false)
    constraints = Keyword.get(opts, :constraints, [])
    name = Keyword.get(opts, :name)

    with {:ok, inner} <- do_gleam_type(name, type, constraints) do
      {:ok, maybe_option(inner, nullable?)}
    end
  end

  defp do_gleam_type(name, type, constraints) do
    case normalize(type, constraints) do
      {:ok, {:scalar, :string}} ->
        {:ok, "String"}

      {:ok, {:scalar, :integer}} ->
        {:ok, "Int"}

      {:ok, {:scalar, :boolean}} ->
        {:ok, "Bool"}

      {:ok, {:scalar, :float}} ->
        {:ok, "Float"}

      {:ok, {:scalar, :decimal}} ->
        {:ok, "Float"}

      {:ok, {:scalar, :uuid}} ->
        {:ok, "String"}

      {:ok, {:scalar, :term}} ->
        {:ok, "String"}

      {:ok, {:constrained_atom, values}} ->
        {:ok, gleam_constrained_atom_type_name(name, values)}

      {:ok, {:reusable_union, module, _variants}} ->
        {:ok, AshGleam.ReusableType.type_name(module)}

      {:ok, {:array, inner}} ->
        item_constraints =
          constraints
          |> Keyword.get(:items, [])
          |> List.wrap()

        nil_items? = Keyword.get(constraints, :nil_items?, false)

        with {:ok, inner} <- do_gleam_type(name, inner, item_constraints) do
          inner = if nil_items?, do: "Option(#{inner})", else: inner
          {:ok, "List(#{inner})"}
        end

      {:ok, {:resource, module}} ->
        {:ok, AshGleam.Resource.Info.gleam_type_name!(module)}

      :error ->
        :error
    end
  end

  defp maybe_option(inner, true), do: "Option(#{inner})"
  defp maybe_option(inner, false), do: inner

  defp supported_union_variant?(%{fields: fields}) do
    Enum.all?(fields, fn field ->
      supported_union_payload?(field.type, field.constraints)
    end)
  end

  defp supported_union_payload?(type, constraints) do
    case normalize(type, constraints) do
      {:ok, {:scalar, _}} -> true
      {:ok, {:reusable_union, _, variants}} -> Enum.all?(variants, &supported_union_variant?/1)
      {:ok, {:array, inner}} -> supported_union_payload?(inner, [])
      {:ok, {:resource, _}} -> true
      {:ok, {:constrained_atom, []}} -> false
      {:ok, {:constrained_atom, _}} -> true
      :error -> false
    end
  end

  defp normalize_atom_type(type, constraints) do
    case Keyword.take(constraints, @type_constraints) do
      [one_of: values] when is_list(values) and values != [] ->
        {:ok, {:constrained_atom, values}}

      _ ->
        if ash_gleam_resource?(type) do
          {:ok, {:resource, type}}
        else
          :error
        end
    end
  end

  defp gleam_constrained_atom_type_name(name, _values) when is_atom(name) do
    name
    |> Atom.to_string()
    |> Macro.camelize()
  end

  defp gleam_constrained_atom_type_name(nil, values) do
    values
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&(&1 |> Atom.to_string() |> Macro.camelize()))
    |> Enum.join()
  end

  @spec named_union?(term(), Keyword.t()) :: boolean()
  def named_union?(type, constraints \\ []) do
    match?({:ok, {:reusable_union, _, _}}, normalize(type, constraints))
  end

  @spec reusable_type_module(term(), Keyword.t()) :: {:ok, module()} | :error
  def reusable_type_module(type, constraints \\ []) do
    case normalize(type, constraints) do
      {:ok, {:reusable_union, module, _}} -> {:ok, module}
      {:ok, {:array, inner}} -> reusable_type_module(inner)
      _ -> :error
    end
  end

  @spec reusable_type_modules(term(), Keyword.t()) :: [module()]
  def reusable_type_modules(type, constraints \\ []) do
    case normalize(type, constraints) do
      {:ok, {:reusable_union, module, variants}} ->
        nested =
          Enum.flat_map(variants, fn variant ->
            Enum.flat_map(variant.fields, &reusable_type_modules(&1.type, &1.constraints))
          end)

        [module | nested]

      {:ok, {:array, inner}} ->
        item_constraints =
          constraints
          |> Keyword.get(:items, [])
          |> List.wrap()

        reusable_type_modules(inner, item_constraints)

      _ ->
        []
    end
    |> Enum.uniq()
  end

  @spec scalar_types() :: [atom()]
  def scalar_types, do: @scalar_types

  @spec ash_gleam_resource?(module()) :: boolean()
  def ash_gleam_resource?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and Spark.Dsl.is?(module, Ash.Resource) and
      AshGleam.Resource.Info.ash_gleam_resource?(module)
  end

  def ash_gleam_resource?(_), do: false
end
