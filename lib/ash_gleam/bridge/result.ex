# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Bridge.Result do
  @moduledoc false

  def encode({:ok, value}, encoder), do: {:ok, encoder.(value)}

  def encode({:error, error}, _encoder),
    do: {:error, Exception.message(Ash.Error.to_error_class(error))}

  def encode(value, encoder), do: {:ok, encoder.(value)}
end
