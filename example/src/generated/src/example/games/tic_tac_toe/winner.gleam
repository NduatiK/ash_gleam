import generated/src/example/games/tic_tac_toe/player.{type Player}

pub type Winner {
  Player(value: Player)
  Draw
  None
}
