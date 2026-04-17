defmodule Example.Games do
  use Ash.Domain,
    otp_app: :example,
    extensions: [AshGleam.FFI]

  gleam_ffi do
    resource Example.Games.TicTacToe do
      # action :create_project, :create
      # action :get_project, :get
    end
  end

  resources do
    resource Example.Games.TicTacToe do
      define :new_tictactoe, action: :create
      define :get_tictactoe, action: :read, get_by: :id
    end
  end
end
