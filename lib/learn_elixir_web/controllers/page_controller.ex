defmodule LearnElixirWeb.PageController do
  use LearnElixirWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
