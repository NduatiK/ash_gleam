defmodule AshGleam.TestProject do
  use Ash.Resource,
    otp_app: :ash_gleam,
    domain: AshGleam.TestDomain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGleam.Resource, AshGleam.Actions]

  ets do
    private? false
    table :ash_gleam_test_projects
  end

  gleam do
    type_name "Project"
    module_name "project_item"

    actions do
      action :complete_all_tasks, __MODULE__ do
        argument :project, __MODULE__, allow_nil?: false

        run &:test_gleam.complete_all_tasks/1
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true

    attribute :items, {:array, AshGleam.TestTask},
      allow_nil?: false,
      default: [],
      public?: true
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :items]
    end

    update :update do
      accept [:name, :items]
      require_atomic? false
    end

    destroy :destroy

    read :get do
      get_by [:id]
    end
  end
end
