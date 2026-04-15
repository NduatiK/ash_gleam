defmodule AshGleam.TestDomain do
  use Ash.Domain,
    otp_app: :ash_gleam,
    extensions: [AshGleam.FFI]

  resources do
    resource AshGleam.TestTodo
  end

  gleam_ffi do
    resource AshGleam.TestTodo do
      action :list_todos, :read
      action :create_todo, :create
      action :get_todo, :get
    end
  end
end
