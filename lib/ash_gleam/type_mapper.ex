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
      {:ok, {:atom_enum, _}} -> true
      {:ok, {:array, inner}} -> supported?(inner)
      {:ok, {:resource, module}} -> ash_gleam_resource?(module)
      :error -> false
    end
  end

  @spec normalize(term(), Keyword.t()) :: {:ok, term()} | :error

  # Pass-through for already-normalized forms produced by recursive normalize calls.
  def normalize({:scalar, _} = normalized, _constraints), do: {:ok, normalized}
  def normalize({:atom_enum, _} = normalized, _constraints), do: {:ok, normalized}
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
        {:ok, {:atom_enum, values}}

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

      {:ok, {:atom_enum, values}} ->
        {:ok, {:atom, one_of: values}}

      {:ok, {:array, inner}} ->
        item_constraints =
          constraints
          |> Keyword.get(:items, [])
          |> List.wrap()

        with {:ok, {inner_type, inner_constraints}} <- ash_type(inner, item_constraints) do
          {:ok, {{:array, inner_type}, items: inner_constraints}}
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

      {:ok, {:atom_enum, values}} ->
        {:ok, gleam_atom_enum_type_name(name, values)}

      {:ok, {:array, inner}} ->
        item_constraints =
          constraints
          |> Keyword.get(:items, [])
          |> List.wrap()

        with {:ok, inner} <- do_gleam_type(name, inner, item_constraints),
             do: {:ok, "List(#{inner})"}

      {:ok, {:resource, module}} ->
        {:ok, AshGleam.Resource.Info.gleam_type_name!(module)}

      :error ->
        :error
    end
  end

  defp maybe_option(inner, true), do: "Option(#{inner})"
  defp maybe_option(inner, false), do: inner

  defp normalize_atom_type(type, constraints) do
    case Keyword.take(constraints, @type_constraints) do
      [one_of: values] when is_list(values) and values != [] ->
        {:ok, {:atom_enum, values}}

      _ ->
        if ash_gleam_resource?(type) do
          {:ok, {:resource, type}}
        else
          :error
        end
    end
  end

  defp gleam_atom_enum_type_name(name, _values) when is_atom(name) do
    name
    |> Atom.to_string()
    |> Macro.camelize()
  end

  defp gleam_atom_enum_type_name(nil, values) do
    values
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&(&1 |> Atom.to_string() |> Macro.camelize()))
    |> Enum.join()
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
