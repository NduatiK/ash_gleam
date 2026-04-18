# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.GleamBridgeSumTypeTest do
  use ExUnit.Case, async: true

  alias AshGleam.WinnerBridge

  describe "consume with sum type argument" do
    test "passes draw variant through" do
      assert {:ok, :draw} = WinnerBridge.announce_winner(:draw)
    end

    test "passes player variant through" do
      assert {:ok, {:player, :x}} = WinnerBridge.announce_winner({:player, :x})
    end
  end

  describe "expose with sum type return" do
    test "ExposeRunner returns sum type value" do
      assert {:ok, {:player, :x}} =
               AshGleam.GleamBridge.ExposeRunner.call(WinnerBridge, :default_winner, %{})
    end
  end
end
