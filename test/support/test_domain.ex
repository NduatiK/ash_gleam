defmodule AshGleam.TestDomain do
  use Ash.Domain,
    otp_app: :ash_gleam,
    extensions: [AshGleam.Domain]

  resources do
    resource AshGleam.TestTodo
    resource AshGleam.TestEmptyResource
    resource AshGleam.TestProject
    resource AshGleam.TestGame
  end

  gleam do
    ffi do
      resource AshGleam.TestTodo do
        action :list_todos, :read
        action :create_todo, :create
        action :get_todo, :get
        action :first_completed_todo, :first_completed
        action :destroy_todo, :destroy
      end

      resource AshGleam.TestProject do
        action :create_project, :create
        action :get_project, :get
      end
    end

    code_interface do
      resource AshGleam.TestTodo do
        define_gleam_update :mark_completed, action: :update
      end
    end
  end
end
