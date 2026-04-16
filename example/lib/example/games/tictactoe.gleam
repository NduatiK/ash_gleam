import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result.{try_recover as else_try}

// type Mark =
//   String
pub type Mark {
  X
  O
}

type Grid =
  List(Option(Mark))

pub type TicTacToe {
  TicTacToe(board: Grid, current_player: Mark)
}

pub type Error {
  OutOfBounds(x: Int, y: Int)
  AlreadyMarked(x: Int, y: Int, mark: Mark)
}

pub fn new() -> TicTacToe {
  let grid = list.repeat(None, 9)
  let assert [mark, ..] = list.shuffle([X, O])
  TicTacToe(grid, mark)
}

pub fn mark(game: TicTacToe, x: Int, y: Int) -> Result(TicTacToe, Error) {
  let TicTacToe(grid: grid, turn: mark) = game
  let position = #(x, y)
  case { get(grid, position) } {
    Ok(None) -> {
      let grid = put(grid, position, Some(mark))
      let mark = next_turn(mark)
      let game = TicTacToe(grid: grid, turn: mark)
      Ok(game)
    }

    Ok(Some(mark)) -> {
      Error(AlreadyMarked(x, y, mark))
    }

    Error(Nil) -> {
      Error(OutOfBounds(x, y))
    }
  }
}

pub fn win(game: TicTacToe) -> Result(Mark, Nil) {
  let TicTacToe(grid: grid, ..) = game

  // Check all rows
  use _ <- else_try(check(grid, [#(1, 1), #(1, 2), #(1, 3)]))
  use _ <- else_try(check(grid, [#(2, 1), #(2, 2), #(2, 3)]))
  use _ <- else_try(check(grid, [#(3, 1), #(3, 2), #(3, 3)]))

  // Check all columns
  use _ <- else_try(check(grid, [#(1, 1), #(2, 1), #(3, 1)]))
  use _ <- else_try(check(grid, [#(1, 2), #(2, 2), #(3, 2)]))
  use _ <- else_try(check(grid, [#(1, 3), #(2, 3), #(3, 3)]))

  // Check \ diagonal
  use _ <- else_try(check(grid, [#(1, 1), #(2, 2), #(3, 3)]))

  // Check / diagonal
  use _ <- else_try(check(grid, [#(1, 3), #(2, 2), #(3, 1)]))

  Error(Nil)
}

fn next_turn(mark: Mark) -> Mark {
  case mark {
    X -> O
    O -> X
  }
}

fn check(grid: Grid, coordinates: List(#(Int, Int))) -> Result(Mark, Nil) {
  let marks =
    coordinates
    |> list.map(get(grid, _))
    |> option.values()

  case marks {
    [x, y, z] if x == y && y == z -> Ok(x)
    _other -> Error(Nil)
  }
}

fn get(grid: Grid, position: #(Int, Int)) -> Option(Mark) {
  let index = {
    position.0 + position.1 * 3
  }
  case { index >= 0 && index <= 9 } {
    False -> None
    True -> {
      let assert Ok(value) = list.at(grid, index)
      value
    }
  }
}

fn put(grid: Grid, position: #(Int, Int), value: Mark) -> v {
  let index = {
    position.0 + position.1 * 3
  }
  list.insert(grid, index, Some(mark))
}
