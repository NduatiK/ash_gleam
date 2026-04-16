defmodule Example.Games do
  use Ash.Domain,
    otp_app: :example,
    extensions: [AshGleam.FFI]

  resources do
    resource Example.Games.TicTacToe
  end

  gleam_ffi do
    resource Example.Games.TicTacToe do
      # action :create_project, :create
      # action :get_project, :get
    end
  end
end
