defmodule AshGleam.TestGame do
  use Ash.Resource,
    otp_app: :ash_gleam,
    domain: AshGleam.TestDomain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGleam.Resource, AshGleam.Actions]

  ets do
    private? false
    table :ash_gleam_test_games
  end

  gleam do
    type_name "Game"
    module_name "game_item"
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :board, {:array, :atom} do
      public? true
      constraints items: [one_of: [:x, :o]]
      default [nil, nil, nil, nil, nil, nil, nil, nil, nil]
    end

    attribute :current_player, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:x, :o]
      default :x
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:in_progress, :finished]
      default :in_progress
    end

    attribute :winner, :atom do
      allow_nil? true
      public? true
      constraints one_of: [:x, :o, :draw]
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :current_player, :status, :winner]
    end

    update :update do
      accept [:name, :current_player, :status, :winner]
      require_atomic? false
    end

    destroy :destroy

    read :get do
      get_by [:id]
    end
  end
end
