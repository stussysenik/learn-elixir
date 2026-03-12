defmodule LearnElixir.Math.Step do
  @moduledoc "A single structured reasoning step for a math plan."

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:position, :integer)
    field(:title, :string)
    field(:detail, :string)
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [:position, :title, :detail])
    |> validate_required([:position, :title, :detail])
    |> validate_number(:position, greater_than: 0)
    |> validate_length(:title, min: 3)
    |> validate_length(:detail, min: 8)
  end
end
