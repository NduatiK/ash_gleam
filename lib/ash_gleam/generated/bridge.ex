# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Generated.Bridge do
  @moduledoc false

  def encode_result(result, encoder), do: AshGleam.Bridge.Result.encode(result, encoder)

  def decode_create(builder, resource, field_names \\ nil),
    do: AshGleam.Bridge.Decode.create(builder, resource, field_names)

  def decode_action(builder, arguments), do: AshGleam.Bridge.Decode.action(builder, arguments)

  def apply_read_builder(query, resource, builder),
    do: AshGleam.Bridge.Query.apply_read_builder(query, resource, builder)
end
