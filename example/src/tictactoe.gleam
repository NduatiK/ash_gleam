import generated/src/board
import generated/src/current_player
import generated/src/tic_tac_toe.{type TicTacToe, TicTacToe}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result.{try_recover as else_try}

type Grid =
  List(board.Board)

pub type Error {
  OutOfBounds(x: Int, y: Int)
  AlreadyMarked(x: Int, y: Int, mark: board.Board)
}

pub fn mark(game: TicTacToe, x: Int, y: Int) -> Result(TicTacToe, Error) {
  case { peek(game, x, y) } {
    Ok(board.Empty) -> {
      let board =
        put(game.board, x, y, case game.current_player {
          current_player.O -> board.O
          current_player.X -> board.X
        })
      let current_player = next_turn(game.current_player)
      let game = TicTacToe(..game, board:, current_player:)
      Ok(game)
    }

    Ok(mark) -> {
      Error(AlreadyMarked(x, y, mark))
    }

    Error(error) -> {
      Error(error)
    }
  }
}

pub fn win(game: TicTacToe) -> Result(board.Board, Nil) {
  // Check all rows
  use _ <- else_try(check(game.board, [#(1, 1), #(1, 2), #(1, 3)]))
  use _ <- else_try(check(game.board, [#(2, 1), #(2, 2), #(2, 3)]))
  use _ <- else_try(check(game.board, [#(3, 1), #(3, 2), #(3, 3)]))

  // Check all columns
  use _ <- else_try(check(game.board, [#(1, 1), #(2, 1), #(3, 1)]))
  use _ <- else_try(check(game.board, [#(1, 2), #(2, 2), #(3, 2)]))
  use _ <- else_try(check(game.board, [#(1, 3), #(2, 3), #(3, 3)]))

  // Check \ diagonal
  use _ <- else_try(check(game.board, [#(1, 1), #(2, 2), #(3, 3)]))

  // Check / diagonal
  use _ <- else_try(check(game.board, [#(1, 3), #(2, 2), #(3, 1)]))

  Error(Nil)
}

fn next_turn(mark: current_player.CurrentPlayer) -> current_player.CurrentPlayer {
  case mark {
    current_player.X -> current_player.O
    current_player.O -> current_player.X
  }
}

fn check(grid: Grid, coordinates: List(#(Int, Int))) -> Result(_, Nil) {
  let marks =
    coordinates
    |> list.map(get(grid, _))
    |> result.values

  case marks {
    [x, y, z] if x == y && y == z -> Ok(x)
    _other -> Error(Nil)
  }
}

pub fn peek(game: TicTacToe, x: Int, y: Int) {
  let position = #(x, y)
  case { get(game.board, position) } {
    Ok(mark) -> {
      Ok(mark)
    }

    Error(Nil) -> {
      Error(OutOfBounds(x, y))
    }
  }
}

fn get(grid: Grid, position: #(Int, Int)) {
  let index = {
    position.0 + position.1 * 3
  }
  case { index >= 0 && index < 9 } {
    False -> Error(Nil)
    True -> {
      case list.drop(grid, index - 1) {
        [value, ..] -> Ok(value)
        _ -> Error(Nil)
      }
    }
  }
}

fn put(grid: Grid, x: Int, y: Int, value: board.Board) {
  let index = {
    x + y * 3
  }

  case list.split(grid, index - 1) {
    #(before, [board.Empty, ..rest]) -> list.append(before, [value, ..rest])
    _ -> grid
  }
}
