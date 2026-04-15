# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Dsl.FFIAction do
  @moduledoc false
  defstruct [:ffi_name, :action, :__identifier__, :__spark_metadata__]
end

defmodule AshGleam.Dsl.FFIResource do
  @moduledoc false
  defstruct [:resource, :actions, :__identifier__, :__spark_metadata__]
end
