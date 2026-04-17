defmodule Example.Games.TicTacToe.Winner do
  alias Example.Games.TicTacToe.Player
  use AshSumType

  variant :player do
    field :value, Player
  end

  variant :draw
  variant :none
end
