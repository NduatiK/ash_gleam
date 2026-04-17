# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Codec.Union do
  @moduledoc false

  def encode(value, variants) when is_atom(value) do
    variant = fetch_variant!(variants, value)

    case variant.fields do
      [] -> value
      _ -> raise ArgumentError, "expected tuple payload for variant #{inspect(value)}"
    end
  end

  def encode(value, variants) when is_tuple(value) do
    [type | payload] = Tuple.to_list(value)
    variant = fetch_variant!(variants, type)
    encoded = encode_payload(payload, variant.fields)

    List.to_tuple([type | encoded])
  end

  def encode(value, _variants) do
    raise ArgumentError,
          "expected atom or tagged tuple for reusable union value, got: #{inspect(value)}"
  end

  def decode(value, variants) when is_atom(value) do
    variant = fetch_variant!(variants, value)

    case variant.fields do
      [] -> value
      _ -> raise ArgumentError, "expected tuple payload for variant #{inspect(value)}"
    end
  end

  def decode(value, variants) when is_tuple(value) do
    [type | payload] = Tuple.to_list(value)
    variant = fetch_variant!(variants, type)
    decoded = decode_payload(payload, variant.fields)

    List.to_tuple([type | decoded])
  end

  def decode(value, _variants) do
    raise ArgumentError,
          "expected atom or tagged tuple for reusable union value, got: #{inspect(value)}"
  end

  defp encode_payload(values, fields) when length(values) == length(fields) do
    Enum.zip_with(values, fields, fn value, field ->
      AshGleam.Marshal.input!(field.type, value,
        allow_nil?: field.allow_nil?,
        constraints: field.constraints
      )
    end)
  end

  defp encode_payload(values, fields) do
    raise ArgumentError,
          "expected #{length(fields)} payload value(s), got #{length(values)}: #{inspect(values)}"
  end

  defp decode_payload(values, fields) when length(values) == length(fields) do
    Enum.zip_with(values, fields, fn value, field ->
      AshGleam.Marshal.output!(field.type, value,
        allow_nil?: field.allow_nil?,
        constraints: field.constraints
      )
    end)
  end

  defp decode_payload(values, fields) do
    raise ArgumentError,
          "expected #{length(fields)} payload value(s), got #{length(values)}: #{inspect(values)}"
  end

  defp fetch_variant!(variants, type) do
    Enum.find(variants, &(&1.name == type)) ||
      raise ArgumentError, "unknown union variant #{inspect(type)}"
  end
end
