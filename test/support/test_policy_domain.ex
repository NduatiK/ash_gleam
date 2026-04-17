defmodule AshGleam.TestPolicyDomain do
  use Ash.Domain,
    otp_app: :ash_gleam,
    extensions: [AshGleam.Domain]

  resources do
    resource AshGleam.TestPolicyTodo
  end

  gleam do
    code_interface do
      resource AshGleam.TestPolicyTodo do
        define_gleam_update :mark_completed, action: :update
      end
    end
  end
end
