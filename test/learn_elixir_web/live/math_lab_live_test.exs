defmodule LearnElixirWeb.MathLabLiveTest do
  use LearnElixirWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the collaborative math lab", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Shared AI Control Room"
    assert html =~ "Thinking roster"
    assert html =~ "Dispatch Problem"
  end
end
