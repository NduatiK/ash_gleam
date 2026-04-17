import generated/src/example/games/tic_tac_toe/mark.{type Mark}
import generated/src/example/games/tic_tac_toe/player.{type Player}
import generated/src/example/games/tic_tac_toe/winner.{type Winner}
import gleam/option.{type Option}

pub type TicTacToe {
  TicTacToe(
    id: String,
    board: List(Mark),
    current_player: Player,
    winner: Option(Winner),
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

pub fn id_asc() -> TicTacToeSort {
  Id(Asc)
}

pub fn id_desc() -> TicTacToeSort {
  Id(Desc)
}

pub fn board_asc() -> TicTacToeSort {
  Board(Asc)
}

pub fn board_desc() -> TicTacToeSort {
  Board(Desc)
}

pub fn current_player_asc() -> TicTacToeSort {
  CurrentPlayer(Asc)
}

pub fn current_player_desc() -> TicTacToeSort {
  CurrentPlayer(Desc)
}

pub fn winner_asc() -> TicTacToeSort {
  Winner(Asc)
}

pub fn winner_desc() -> TicTacToeSort {
  Winner(Desc)
}

pub type TicTacToeFilter {
  IdEq(String)
  BoardEq(List(Mark))
  CurrentPlayerEq(Player)
  WinnerEq(Winner)
}

pub fn id_eq(value: String) -> TicTacToeFilter {
  IdEq(value)
}

pub fn board_eq(value: List(Mark)) -> TicTacToeFilter {
  BoardEq(value)
}

pub fn current_player_eq(value: Player) -> TicTacToeFilter {
  CurrentPlayerEq(value)
}

pub fn winner_eq(value: Winner) -> TicTacToeFilter {
  WinnerEq(value)
}
