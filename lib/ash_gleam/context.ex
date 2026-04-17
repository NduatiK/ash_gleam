# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Context do
  @spec new(Keyword.t()) :: {:context, Keyword.t()}
  def new(opts), do: {:context, opts}

  @spec to_opts({:context, Keyword.t()}) :: Keyword.t()
  def to_opts({:context, opts}), do: opts
end
