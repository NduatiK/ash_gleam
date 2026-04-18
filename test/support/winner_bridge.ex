defmodule AshGleam.WinnerBridge do
  use AshGleam.GleamBridge

  gleam do
    consume do
      function :announce_winner, AshGleam.TestWinner do
        argument :winner, AshGleam.TestWinner, allow_nil?: false

        run &:test_gleam.announce_winner/1
      end
    end

    expose do
      function :default_winner, AshGleam.TestWinner do
        run fn -> {:ok, {:player, :x}} end
      end
    end
  end
end
