defmodule Lightning.Workflows.Graph do
  @moduledoc """
  Utility to construct and manipulate a graph/plan made out of Jobs
  """
  defstruct [:digraph, :root, :jobs]

  @type vertex :: {Ecto.UUID.t()}

  @type t :: %__MODULE__{
          digraph: :digraph.graph(),
          root: vertex(),
          jobs: [Lightning.Jobs.Job.t()]
        }

  @spec new(jobs :: [Lightning.Jobs.Job.t()]) :: __MODULE__.t()
  def new(jobs) when is_list(jobs) do
    g = :digraph.new()

    for j <- jobs do
      :digraph.add_vertex(g, to_vertex(j))
    end

    for j <- jobs do
      if j.trigger.type in [:on_job_failure, :on_job_success] do
        :digraph.add_edge(g, to_vertex(j.trigger.upstream_job), to_vertex(j))
      end
    end

    %__MODULE__{digraph: g, root: get_root(g), jobs: jobs}
  end

  @spec remove(__MODULE__.t(), Ecto.UUID.t()) :: __MODULE__.t()
  def remove(%__MODULE__{digraph: g} = graph, job_id) do
    vertex =
      :digraph.vertices(g)
      |> Enum.find(fn {id} -> id == job_id end)

    :digraph.del_vertex(g, vertex)
    prune(graph)

    %{graph | jobs: vertices(graph)}
  end

  @spec vertices(__MODULE__.t()) :: [Lightning.Jobs.Job.t()]
  def vertices(%__MODULE__{digraph: g, jobs: jobs}) do
    :digraph_utils.topsort(g)
    |> Enum.map(fn {id} ->
      Enum.find(jobs, &match?(%{id: ^id}, &1))
    end)
  end

  defp get_root(g) do
    {:yes, root} = :digraph_utils.arborescence_root(g)
    root
  end

  defp get_reachable(%__MODULE__{} = graph) do
    [graph.root] ++
      :digraph_utils.reachable_neighbours([graph.root], graph.digraph)
  end

  defp prune(%__MODULE__{} = graph) do
    reachable = get_reachable(graph)

    unreachable =
      :digraph.vertices(graph.digraph)
      |> Enum.filter(fn v -> v not in reachable end)

    true = :digraph.del_vertices(graph.digraph, unreachable)
  end

  defp to_vertex(job) do
    {job.id}
  end
end
