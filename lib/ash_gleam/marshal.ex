# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Marshal do
  @moduledoc false

  alias AshGleam.Error.ActionInterop

  @spec input!(term(), term(), Keyword.t()) :: term()
  def input!(type, value, opts \\ []) do
    if is_nil(value) and Keyword.get(opts, :allow_nil?, true) do
      :none
    else
      marshal(type, value, opts, :to_gleam)
    end
  rescue
    error ->
      ActionInterop.raise!("Failed to marshal input",
        resource: Keyword.get(opts, :resource),
        action: Keyword.get(opts, :action),
        details: %{phase: :encode_input, type: type, error: Exception.message(error)}
      )
  end

  @spec output!(term(), term(), Keyword.t()) :: term()
  def output!(type, value, opts \\ []) do
    allow_nil? = Keyword.get(opts, :allow_nil?, false)

    case value do
      :none when allow_nil? ->
        nil

      {:some, inner} when allow_nil? ->
        marshal(type, inner, opts, :from_gleam)

      _ ->
        marshal(type, value, opts, :from_gleam)
    end
  rescue
    error ->
      ActionInterop.raise!("Failed to marshal output",
        resource: Keyword.get(opts, :resource),
        action: Keyword.get(opts, :action),
        details: %{phase: :decode_output, type: type, error: Exception.message(error)}
      )
  end

  @spec to_gleam(module(), struct() | map()) :: tuple()
  def to_gleam(resource, value), do: AshGleam.Codec.Resource.to_gleam(resource, value)

  @spec from_gleam(module(), tuple() | struct() | map()) :: map()
  def from_gleam(resource, value)

  def from_gleam(resource, value), do: AshGleam.Codec.Resource.from_gleam(resource, value)

  defp marshal(type, value, opts, direction)

  defp marshal({:array, _inner} = type, value, opts, :to_gleam) when is_list(value),
    do: AshGleam.Codec.Value.encode(type, value, opts)

  defp marshal({:array, _inner} = type, value, opts, :from_gleam) when is_list(value),
    do: AshGleam.Codec.Value.decode(type, value, opts)

  defp marshal(type, value, opts, :to_gleam) when is_atom(type) do
    AshGleam.Codec.Value.encode(type, value, opts)
  end

  defp marshal(type, value, opts, :from_gleam) when is_atom(type) do
    AshGleam.Codec.Value.decode(type, value, opts)
  end
end
