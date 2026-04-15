# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Dsl.GleamArgument do
  @moduledoc false
  defstruct [:name, :type, :allow_nil?, :__identifier__, :__spark_metadata__]
end

defmodule AshGleam.Dsl.GleamAction do
  @moduledoc false
  defstruct [
    :name,
    :return_type,
    :run,
    :arguments,
    :allow_nil?,
    :__identifier__,
    :__spark_metadata__
  ]
end
