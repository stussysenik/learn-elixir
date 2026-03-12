defmodule LearnElixir.Math.VerifierTest do
  use ExUnit.Case, async: true

  alias LearnElixir.Math.Plan
  alias LearnElixir.Math.Verifier

  test "verifies a matching structured answer" do
    plan = build_plan(60.0)

    assert {:ok, %{status: :verified, expected: 60.0, delta: delta}} = Verifier.verify(plan)
    assert delta == 0.0
  end

  test "flags a mismatch when the answer is wrong" do
    plan = build_plan(61.0)

    assert {:ok, %{status: :mismatch, expected: 60.0, given: 61.0}} = Verifier.verify(plan)
  end

  defp build_plan(answer) do
    {:ok, plan} =
      Plan.new(%{
        problem: "12 * (8 - 3)",
        normalized_expression: "12 * (8 - 3)",
        final_answer: answer,
        confidence: 0.99,
        steps: [
          %{
            "position" => 1,
            "title" => "Normalize",
            "detail" => "Translate the prompt into 12 * (8 - 3)."
          },
          %{
            "position" => 2,
            "title" => "Evaluate",
            "detail" => "Subtract first, then multiply the result by 12."
          }
        ]
      })

    plan
  end
end
