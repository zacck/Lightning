defmodule Lightning.ProjectsTest do
  use Lightning.DataCase, async: true

  alias Lightning.Projects.ProjectUser
  alias Lightning.Projects
  alias Lightning.Projects.Project

  import Lightning.ProjectsFixtures
  import Lightning.AccountsFixtures
  import Lightning.CredentialsFixtures

  describe "projects" do
    @invalid_attrs %{name: nil}

    test "list_projects/0 returns all projects" do
      project = project_fixture() |> unload_relation(:project_users)
      assert Projects.list_projects() == [project]
    end

    test "list_project_credentials/1 returns all project_credentials for a project" do
      user = user_fixture()
      project = project_fixture(project_users: [%{user_id: user.id}])

      credential =
        credential_fixture(
          user_id: user.id,
          project_credentials: [%{project_id: project.id}]
        )

      assert Projects.list_project_credentials(project) ==
               credential.project_credentials |> Repo.preload(:credential)
    end

    test "get_project!/1 returns the project with given id" do
      project = project_fixture() |> unload_relation(:project_users)
      assert Projects.get_project!(project.id) == project

      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project!(Ecto.UUID.generate())
      end
    end

    test "get_project/1 returns the project with given id" do
      assert Projects.get_project(Ecto.UUID.generate()) == nil

      project = project_fixture() |> unload_relation(:project_users)
      assert Projects.get_project(project.id) == project
    end

    test "get_project_with_users!/1 returns the project with given id" do
      user = user_fixture()

      project =
        project_fixture(project_users: [%{user_id: user.id}])
        |> Repo.preload(project_users: [:user])

      assert Projects.get_project_with_users!(project.id) == project
    end

    test "get_project_user!/1 returns the project_user with given id" do
      project_user =
        project_fixture(project_users: [%{user_id: user_fixture().id}]).project_users
        |> List.first()

      assert Projects.get_project_user!(project_user.id) == project_user

      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project_user!(Ecto.UUID.generate())
      end
    end

    test "get_project_user/1 returns the project_user with given id" do
      assert Projects.get_project_user(Ecto.UUID.generate()) == nil

      project_user =
        project_fixture(project_users: [%{user_id: user_fixture().id}]).project_users
        |> List.first()

      assert Projects.get_project_user(project_user.id) == project_user
    end

    test "create_project/1 with valid data creates a project" do
      %{id: user_id} = user_fixture()
      valid_attrs = %{name: "some-name", project_users: [%{user_id: user_id}]}

      assert {:ok, %Project{id: project_id} = project} =
               Projects.create_project(valid_attrs)

      assert project.name == "some-name"

      assert [%{project_id: ^project_id, user_id: ^user_id}] =
               project.project_users
    end

    test "create_project/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Projects.create_project(@invalid_attrs)

      assert {:error, %Ecto.Changeset{}} =
               Projects.create_project(%{"name" => "Can't have spaces!"})
    end

    test "update_project/2 with valid data updates the project" do
      project = project_fixture()
      update_attrs = %{name: "some-updated-name"}

      assert {:ok, %Project{} = project} =
               Projects.update_project(project, update_attrs)

      assert project.name == "some-updated-name"
    end

    test "update_project/2 with invalid data returns error changeset" do
      project = project_fixture() |> unload_relation(:project_users)

      assert {:error, %Ecto.Changeset{}} =
               Projects.update_project(project, @invalid_attrs)

      assert project == Projects.get_project!(project.id)
    end

    test "update_project_user/2 with valid data updates the project_user" do
      project =
        project_fixture(
          project_users: [
            %{
              user_id: user_fixture().id,
              role: :viewer,
              digest: :daily,
              failure_alert: false
            }
          ]
        )

      update_attrs = %{digest: "weekly"}

      assert {:ok, %ProjectUser{} = project_user} =
               Projects.update_project_user(
                 project.project_users |> List.first(),
                 update_attrs
               )

      assert project_user.digest == :weekly
      assert project_user.failure_alert == false
    end

    test "update_project_user/2 with invalid data returns error changeset" do
      project =
        project_fixture(
          project_users: [
            %{
              user_id: user_fixture().id,
              role: :viewer,
              digest: :monthly,
              failure_alert: true
            }
          ]
        )

      project_user = project.project_users |> List.first()

      update_attrs = %{digest: "bad_value"}

      assert {:error, %Ecto.Changeset{}} =
               Projects.update_project_user(project_user, update_attrs)

      assert project_user == Projects.get_project_user!(project_user.id)
    end

    test "delete_project/1 deletes the project" do
      %{
        project: p1,
        w1_job: w1_job
      } = full_project_fixture()

      %{
        project: p2,
        w2_job: w2_job
      } = full_project_fixture()

      {:ok, p1_pu} = p1.project_users |> Enum.fetch(0)

      p1_user = Lightning.Accounts.get_user!(p1_pu.user_id)

      {:ok, p1_work_order} =
        Lightning.WorkOrderService.multi_for(
          :webhook,
          w1_job,
          ~s[{"foo": "bar"}] |> Jason.decode!()
        )
        |> Repo.transaction()

      Lightning.WorkOrderService.retry_attempt_run(
        p1_work_order.attempt_run,
        p1_user
      )

      Lightning.WorkOrderService.multi_for(
        :webhook,
        w2_job,
        ~s[{"foo": "bar"}] |> Jason.decode!()
      )
      |> Repo.transaction()

      runs_query = Lightning.Projects.project_runs_query(p1)

      work_order_query = Lightning.Projects.project_workorders_query(p1)

      attempt_query = Lightning.Projects.project_attempts_query(p1)

      attempt_run_query = Lightning.Projects.project_attempt_run_query(p1)

      workflows_ir_query =
        Lightning.Projects.project_workflows_invocation_reason(p1)

      pu_ir_query = Lightning.Projects.project_users_invocation_reasons(p1)

      pu_query = Lightning.Projects.project_users_query(p1)

      pc_query = Lightning.Projects.project_credentials_query(p1)

      workflows_query = Lightning.Projects.project_workflows_query(p1)

      jobs_query = Lightning.Projects.project_jobs_query(p1)

      assert runs_query |> Repo.aggregate(:count, :id) == 3

      assert work_order_query |> Repo.aggregate(:count, :id) == 1

      assert attempt_query |> Repo.aggregate(:count, :id) == 2

      assert attempt_run_query |> Repo.aggregate(:count, :id) == 3

      assert workflows_ir_query |> Repo.aggregate(:count, :id) == 1

      assert pu_ir_query |> Repo.aggregate(:count, :id) == 1

      assert pu_query |> Repo.aggregate(:count, :id) == 1

      assert pc_query |> Repo.aggregate(:count, :id) == 1

      assert workflows_query |> Repo.aggregate(:count, :id) == 2,
             "There should be only two workflows"

      assert jobs_query |> Repo.aggregate(:count, :id) == 5,
             "There should be only five jobs"

      assert {:ok, %Project{}} = Projects.delete_project(p1)

      assert runs_query |> Repo.aggregate(:count, :id) == 0

      assert work_order_query |> Repo.aggregate(:count, :id) == 0

      assert attempt_query |> Repo.aggregate(:count, :id) == 0

      assert attempt_run_query |> Repo.aggregate(:count, :id) == 0

      assert pu_query |> Repo.aggregate(:count, :id) == 0

      assert pc_query |> Repo.aggregate(:count, :id) == 0

      assert workflows_query |> Repo.aggregate(:count, :id) == 0

      assert jobs_query |> Repo.aggregate(:count, :id) == 0

      assert workflows_ir_query |> Repo.aggregate(:count, :id) == 0

      assert pu_ir_query |> Repo.aggregate(:count, :id) == 0

      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project!(p1.id)
      end

      assert p2.id == Projects.get_project!(p2.id).id

      assert Lightning.Projects.project_runs_query(p2)
             |> Repo.aggregate(:count, :id) == 1
    end

    test "change_project/1 returns a project changeset" do
      project = project_fixture()
      assert %Ecto.Changeset{} = Projects.change_project(project)
    end

    test "get projects for a given user" do
      user = user_fixture()
      other_user = user_fixture()

      project_1 =
        project_fixture(
          project_users: [%{user_id: user.id}, %{user_id: other_user.id}]
        )
        |> Repo.reload()

      project_2 =
        project_fixture(project_users: [%{user_id: user.id}])
        |> Repo.reload()

      assert [project_1, project_2] == Projects.get_projects_for_user(user)
      assert [project_1] == Projects.get_projects_for_user(other_user)
    end

    test "get_project_user_role/2" do
      user_1 = user_fixture()
      user_2 = user_fixture()

      project =
        project_fixture(
          project_users: [
            %{user_id: user_1.id, role: :admin},
            %{user_id: user_2.id, role: :editor}
          ]
        )
        |> Repo.reload()

      assert Projects.get_project_user_role(user_1, project) == :admin
      assert Projects.get_project_user_role(user_2, project) == :editor
    end

    test "export_project/2 as yaml" do
      %{project: project} = full_project_fixture()
      expected_yaml = File.read!("test/fixtures/canonical_project.yaml")
      {:ok, generated_yaml} = Projects.export_project(:yaml, project.id)

      assert generated_yaml == expected_yaml
    end
  end
end
