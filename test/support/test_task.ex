defmodule AshGleam.TestTask do
  use Ash.Resource,
    domain: AshGleam.TestDomain,
    data_layer: :embedded,
    extensions: [AshGleam.Resource, AshGleam.Actions]

  gleam do
    type_name "Task"
    module_name("task")
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :completed, :boolean, allow_nil?: false, default: false, public?: true
    attribute :priority, :integer, allow_nil?: false, default: 1, public?: true
  end

  actions do
    create :create do
      primary? true
      accept [:title, :completed, :priority]
    end
  end
end
