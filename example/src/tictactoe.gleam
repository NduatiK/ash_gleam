import generated/src/example/games/tic_tac_toe/mark
import generated/src/example/games/tic_tac_toe/player
import generated/src/example/games/tic_tac_toe/winner
import generated/src/tic_tac_toe.{type TicTacToe, TicTacToe}
import gleam/list
import gleam/result.{try_recover as else_try}

type Grid =
  List(mark.Mark)

pub type Error {
  OutOfBounds(x: Int, y: Int)
  AlreadyMarked(x: Int, y: Int, mark: mark.Mark)
}

pub fn mark(game: TicTacToe, x: Int, y: Int) -> Result(TicTacToe, Error) {
  case { peek(game, x, y) } {
    Ok(mark.Empty) -> {
      let board =
        put(game.board, x, y, case game.current_player {
          player.O -> mark.O
          player.X -> mark.X
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

pub fn win(game: TicTacToe) -> winner.Winner {
  {
    use _ <- else_try(check(game.board, [#(0, 0), #(0, 1), #(0, 2)]))
    use _ <- else_try(check(game.board, [#(1, 0), #(1, 1), #(1, 2)]))
    use _ <- else_try(check(game.board, [#(2, 0), #(2, 1), #(2, 2)]))

    // Check all columns
    use _ <- else_try(check(game.board, [#(0, 0), #(1, 0), #(2, 0)]))
    use _ <- else_try(check(game.board, [#(0, 1), #(1, 1), #(2, 1)]))
    use _ <- else_try(check(game.board, [#(0, 2), #(1, 2), #(2, 2)]))

    // Check \ diagonal
    use _ <- else_try(check(game.board, [#(0, 0), #(1, 1), #(2, 2)]))

    // Check / diagonal
    use _ <- else_try(check(game.board, [#(0, 2), #(1, 1), #(2, 0)]))

    case is_filled(game) {
      True -> Ok(winner.Draw)
      False -> Error(Nil)
    }
  }
  |> result.unwrap(winner.None)
}

fn is_filled(game: TicTacToe) -> Bool {
  !list.any(game.board, fn(v) { v == mark.Empty })
}

fn next_turn(mark: player.Player) -> player.Player {
  case mark {
    player.O -> player.X
    player.X -> player.O
  }
}

fn check(grid: Grid, coordinates: List(#(Int, Int))) -> Result(_, Nil) {
  let marks =
    coordinates
    |> list.map(get(grid, _))
    |> result.values

  case marks {
    [x, y, z] if x == y && y == z && x != mark.Empty -> {
      Ok(case x {
        mark.O -> winner.Player(player.O)
        _ -> winner.Player(player.X)
      })
    }
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
  let index = position.0 + position.1 * 3

  case { index >= 0 && index < 9 } {
    False -> Error(Nil)
    True -> {
      case list.drop(grid, index) {
        [value, ..] -> Ok(value)
        _ -> Error(Nil)
      }
    }
  }
}

fn put(grid: Grid, x: Int, y: Int, value: mark.Mark) {
  let index = {
    x + y * 3
  }

  case list.split(grid, index) {
    #(before, [mark.Empty, ..rest]) -> list.append(before, [value, ..rest])
    _ -> grid
  }
}
