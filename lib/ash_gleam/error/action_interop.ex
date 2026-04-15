# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Error.ActionInterop do
  @moduledoc false
  defexception [:message, :resource, :action, :details]
end
