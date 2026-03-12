defmodule LearnElixirWeb.PageControllerTest do
  use LearnElixirWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ "Supervised math agents"
    assert html =~ "Give the room a problem"
  end
end
