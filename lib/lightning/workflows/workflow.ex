defmodule Lightning.Workflows.Workflow do
  @moduledoc """
  Ecto model for Workflows.

  A Workflow contains the fields for defining a workflow.

  * `name`
    A plain text identifier
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Lightning.Jobs.Job
  alias Lightning.Projects.Project

  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: Ecto.UUID.t() | nil,
          name: String.t() | nil,
          project: nil | Project.t() | Ecto.Association.NotLoaded.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "workflows" do
    field(:name, :string)

    has_many(:jobs, Job)
    belongs_to :project, Project

    timestamps()
  end

  @doc false
  def changeset(workflow, attrs) do
    workflow
    |> cast(attrs, [:name, :project_id])
    |> validate_required([:project_id])
    |> unique_constraint([:name, :project_id],
      message: "A workflow with this name does already exist in this project."
    )
  end
end