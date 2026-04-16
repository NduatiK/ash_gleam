defmodule AshGleam.TestGleamBridge do
  @moduledoc false

  def first_completed_todo do
    AshGleam.TestTodo
    |> Ash.Query.for_read(:first_completed, %{}, domain: AshGleam.TestDomain)
    |> Ash.read_one!(domain: AshGleam.TestDomain)
    |> AshGleam.Marshal.to_gleam(AshGleam.TestTodo)
  end
end
