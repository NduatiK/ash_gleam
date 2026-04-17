defmodule AshGleam.TestPlayer do
  use AshSumType

  variant :x
  variant :o
end

defmodule AshGleam.TestWinner do
  use AshSumType

  variant :draw

  variant :player do
    field :player, AshGleam.TestPlayer
  end
end
