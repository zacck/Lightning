defmodule LightningWeb.API.ProjectControllerTest do
  use LightningWeb.ConnCase, async: true

  import Lightning.ProjectsFixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "without a token" do
    test "gets a 401", %{conn: conn} do
      conn = get(conn, ~p"/api/projects")
      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
    end
  end

  describe "with invalid token" do
    test "gets a 401", %{conn: conn} do
      token = "Oooops"
      conn = conn |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
      conn = get(conn, ~p"/api/projects")
      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
    end
  end

  describe "index" do
    setup [:assign_bearer_for_api, :create_project_for_current_user]

    test "lists all projects i belong to", %{conn: conn, project: project} do
      conn = get(conn, ~p"/api/projects")
      response = json_response(conn, 200)

      assert response["data"] == [
               %{
                 "attributes" => %{"name" => "a-test-project"},
                 "id" => project.id,
                 "links" => %{
                   "self" => "http://localhost:4002/api/projects/#{project.id}"
                 },
                 "relationships" => %{},
                 "type" => "projects"
               }
             ]
    end

    test "Other user don't have access to user project", %{
      conn: conn,
      project: project
    } do
      other_user = Lightning.AccountsFixtures.user_fixture()

      token =
        other_user
        |> Lightning.Accounts.generate_api_token()

      conn = conn |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")

      Lightning.ProjectsFixtures.project_fixture(
        project_users: [%{user_id: other_user.id}]
      )

      conn = get(conn, ~p"/api/projects")
      response = json_response(conn, 200)

      refute response["data"] == [
               %{
                 "attributes" => %{"name" => "a-test-project"},
                 "id" => project.id,
                 "links" => %{
                   "self" => "http://localhost:4002/api/projects/#{project.id}"
                 },
                 "relationships" => %{},
                 "type" => "projects"
               }
             ]
    end
  end

  describe "show" do
    setup [:assign_bearer_for_api, :create_project_for_current_user]

    test "with token for other project", %{conn: conn} do
      other_project = project_fixture()
      conn = get(conn, ~p"/api/projects/#{other_project.id}")
      assert json_response(conn, 404) == %{"error" => "Not Found"}
    end

    test "shows the project", %{conn: conn, project: project} do
      conn = get(conn, Routes.api_project_path(conn, :show, project))
      response = json_response(conn, 200)

      assert response["data"] == %{
               "attributes" => %{"name" => "a-test-project"},
               "id" => project.id,
               "links" => %{
                 "self" => "http://localhost:4002/api/projects/#{project.id}"
               },
               "relationships" => %{},
               "type" => "projects"
             }
    end
  end
end
