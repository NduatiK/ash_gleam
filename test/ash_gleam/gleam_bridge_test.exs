# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.GleamBridgeTest do
  use ExUnit.Case, async: true

  alias AshGleam.MathBridge

  describe "consume" do
    test "calls gleam function with positional args" do
      assert {:ok, 5} = MathBridge.add_in_gleam(2, 3)
    end
  end

  describe "round trip" do
    test "elixir -> gleam -> elixir" do
      assert {:ok, 5} = MathBridge.round_trip_add(2, 3)
    end
  end

  describe "consume_functions/1" do
    test "returns declared consume functions" do
      fns = AshGleam.GleamBridge.Info.consume_functions(MathBridge)
      names = Enum.map(fns, & &1.name)
      assert :add_in_gleam in names
    end
  end

  describe "expose_functions/1" do
    test "returns declared expose functions" do
      fns = AshGleam.GleamBridge.Info.expose_functions(MathBridge)
      names = Enum.map(fns, & &1.name)
      assert :add in names
      assert :greet in names
    end
  end
end
