# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Dsl.GleamUpdate do
  @moduledoc false
  defstruct [:name, :action, :gleam_action, :__identifier__, :__spark_metadata__]
end

defmodule AshGleam.Dsl.GleamUpdateResource do
  @moduledoc false
  defstruct [:resource, :updates, :__identifier__, :__spark_metadata__]
end
