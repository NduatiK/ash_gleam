# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Dsl.BridgeArgument do
  @moduledoc false
  defstruct [:name, :type, :constraints, :allow_nil?, :__identifier__, :__spark_metadata__]
end

defmodule AshGleam.Dsl.ConsumeFunction do
  @moduledoc false
  defstruct [
    :name,
    :return_type,
    :constraints,
    :run,
    :arguments,
    :allow_nil?,
    :__identifier__,
    :__spark_metadata__
  ]
end

defmodule AshGleam.Dsl.ExposeFunction do
  @moduledoc false
  defstruct [
    :name,
    :return_type,
    :constraints,
    :run,
    :arguments,
    :allow_nil?,
    :__identifier__,
    :__spark_metadata__
  ]
end

defmodule AshGleam.Dsl.Consume do
  @moduledoc false
  defstruct [:functions, :__identifier__, :__spark_metadata__]
end

defmodule AshGleam.Dsl.Expose do
  @moduledoc false
  defstruct [:functions, :__identifier__, :__spark_metadata__]
end
