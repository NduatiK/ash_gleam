defmodule AshGleam.TestPolicyTodo do
  use Ash.Resource,
    otp_app: :ash_gleam,
    domain: AshGleam.TestPolicyDomain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGleam.Resource, AshGleam.Actions]

  ets do
    private? false
    table :ash_gleam_test_policy_todos
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :completed, :boolean, allow_nil?: false, default: false, public?: true
    attribute :owner_id, :string, allow_nil?: true, public?: true
  end

  actions do
    defaults [:read]

    create :create do
      accept [:title, :completed, :owner_id]
    end

    update :update do
      accept [:title, :completed]
      require_atomic? false
    end

    action :admin_add, :integer do
      argument :a, :integer, allow_nil?: false
      argument :b, :integer, allow_nil?: false

      run fn input, _context ->
        {:ok, input.arguments.a + input.arguments.b}
      end
    end
  end

  policies do
    policy action(:add) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action(:mark_completed) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action(:update) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action(:gleam_admin_add) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action(:admin_add) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  gleam do
    type_name "PolicyTodo"
    module_name("policy_todo_item")

    actions do
      action :mark_completed, __MODULE__ do
        update? true
        argument :todo, __MODULE__, allow_nil?: false
        run &:test_gleam_policy.mark_completed/1
      end

      action :add, :integer do
        argument :a, :integer, allow_nil?: false
        argument :b, :integer, allow_nil?: false

        run &:test_gleam.add/2
      end

      action :gleam_admin_add, :integer do
        pass_context?(true)
        argument :a, :integer, allow_nil?: false
        argument :b, :integer, allow_nil?: false

        run &:test_gleam.add_with_context/3
      end
    end
  end
end
