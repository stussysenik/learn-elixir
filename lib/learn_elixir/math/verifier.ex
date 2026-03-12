defmodule LearnElixir.Math.Verifier do
  @moduledoc "Verifies structured math output by recomputing the formula with Nx."

  alias LearnElixir.Math.Expression
  alias LearnElixir.Math.Plan

  @tolerance 1.0e-6

  def verify(%Plan{normalized_expression: expression, final_answer: answer}) do
    with {:ok, expected} <- Expression.evaluate_nx(expression) do
      delta = abs(expected - answer)

      {:ok,
       %{
         expected: expected,
         given: answer,
         delta: delta,
         status: if(delta <= @tolerance, do: :verified, else: :mismatch)
       }}
    end
  end
end
