# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.TypeMapper do
  @moduledoc false

  @scalar_types [:string, :integer, :boolean, :float, :decimal, :uuid]
  @scalar_type_modules %{
    Ash.Type.String => :string,
    Ash.Type.Integer => :integer,
    Ash.Type.Boolean => :boolean,
    Ash.Type.Float => :float,
    Ash.Type.Decimal => :decimal,
    Ash.Type.UUID => :uuid
  }

  @spec supported?(term()) :: boolean()
  def supported?(type) do
    case normalize(type) do
      {:ok, {:scalar, _}} -> true
      {:ok, {:array, inner}} -> supported?(inner)
      {:ok, {:resource, module}} -> ash_gleam_resource?(module)
      :error -> false
    end
  end

  @spec normalize(term()) :: {:ok, term()} | :error
  def normalize({:array, inner}) do
    with {:ok, inner} <- normalize(inner) do
      {:ok, {:array, inner}}
    end
  end

  def normalize(type) when type in @scalar_types, do: {:ok, {:scalar, type}}

  def normalize(type) when is_atom(type) do
    cond do
      type in @scalar_types ->
        {:ok, {:scalar, type}}

      mapped = @scalar_type_modules[type] ->
        {:ok, {:scalar, mapped}}

      ash_gleam_resource?(type) ->
        {:ok, {:resource, type}}

      true ->
        :error
    end
  end

  def normalize(_), do: :error

  @spec ash_type(term()) :: {:ok, {term(), Keyword.t()}} | :error
  def ash_type(type) do
    case normalize(type) do
      {:ok, {:scalar, scalar}} ->
        {:ok, {scalar, []}}

      {:ok, {:array, inner}} ->
        with {:ok, {inner_type, inner_constraints}} <- ash_type(inner) do
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

    with {:ok, inner} <- do_gleam_type(type) do
      {:ok, maybe_option(inner, nullable?)}
    end
  end

  defp do_gleam_type(type) do
    case normalize(type) do
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

      {:ok, {:array, inner}} ->
        with {:ok, inner} <- do_gleam_type(inner), do: {:ok, "List(#{inner})"}

      {:ok, {:resource, module}} ->
        {:ok, AshGleam.Resource.Info.gleam_type_name!(module)}

      :error ->
        :error
    end
  end

  defp maybe_option(inner, true), do: "Option(#{inner})"
  defp maybe_option(inner, false), do: inner

  @spec scalar_types() :: [atom()]
  def scalar_types, do: @scalar_types

  @spec ash_gleam_resource?(module()) :: boolean()
  def ash_gleam_resource?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and Spark.Dsl.is?(module, Ash.Resource) and
      AshGleam.Resource.Info.ash_gleam_resource?(module)
  end

  def ash_gleam_resource?(_), do: false
end
