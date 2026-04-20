import generated/src/example/games/tic_tac_toe/mark.{type Mark}
import generated/src/example/games/tic_tac_toe/player.{type Player}
import generated/src/example/games/tic_tac_toe/winner.{type Winner}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}

pub type TicTacToe {
  TicTacToe(
    id: String,
    board: List(Option(Mark)),
    current_player: Player,
    winner: Option(Winner),
    an_example_unsupported_type: Option(Dynamic),
  )
}

pub type Sorter {
  Asc
  Desc
}

pub type TicTacToeSort {
  Id(Sorter)
  Board(Sorter)
  CurrentPlayer(Sorter)
  Winner(Sorter)
}

pub type TicTacToeFilter {
  IdEq(String)
  BoardEq(List(Option(Mark)))
  CurrentPlayerEq(Player)
  WinnerEq(Winner)
}
