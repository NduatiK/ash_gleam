# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Error.ActionInterop do
  @moduledoc false
  defexception [:message, :resource, :action, :details]

  def raise!(message, opts \\ []) do
    raise __MODULE__,
      message: message,
      resource: Keyword.get(opts, :resource),
      action: Keyword.get(opts, :action),
      details:
        opts
        |> Keyword.get(:details, %{})
        |> normalize_details()
  end

  defp normalize_details(%_{} = details), do: Map.from_struct(details)
  defp normalize_details(details) when is_map(details), do: details
  defp normalize_details(details) when is_list(details), do: Map.new(details)
  defp normalize_details(details), do: %{details: details}
end
