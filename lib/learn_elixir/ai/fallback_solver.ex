defmodule LearnElixir.AI.FallbackSolver do
  @moduledoc "Deterministic arithmetic solver used when an LLM is unavailable or invalid."

  alias LearnElixir.Math.Expression
  alias LearnElixir.Math.Plan

  def solve(problem) when is_binary(problem) do
    normalized_expression = Expression.normalize(problem)

    with {:expression, expression} <- ensure_expression(normalized_expression),
         {:ok, answer} <- Expression.evaluate(expression) do
      Plan.new(%{
        problem: String.trim(problem),
        normalized_expression: expression,
        final_answer: answer,
        confidence: 0.99,
        steps: build_steps(problem, expression, answer)
      })
    else
      {:error, :empty_expression} ->
        {:error, "Enter a numeric prompt such as `12 * (8 - 3)` or `18 divided by 6`."}

      {:error, :unsupported_expression} ->
        {:error, "Only arithmetic with +, -, *, /, parentheses, and powers is supported."}

      {:error, :invalid_expression} ->
        {:error, "I could not turn that prompt into a safe arithmetic expression."}

      {:error, :division_by_zero} ->
        {:error, "Division by zero is not allowed."}

      :missing_expression ->
        {:error, "I could not detect a solvable arithmetic expression in that prompt."}
    end
  end

  defp ensure_expression(""), do: {:error, :empty_expression}
  defp ensure_expression(expression), do: {:expression, expression}

  defp build_steps(problem, expression, answer) do
    [
      %{
        "position" => 1,
        "title" => "Normalize the prompt",
        "detail" =>
          "Translate `#{String.trim(problem)}` into the arithmetic expression `#{expression}`."
      },
      %{
        "position" => 2,
        "title" => "Evaluate with operator precedence",
        "detail" =>
          "Compute the expression while respecting parentheses, powers, multiplication, division, addition, and subtraction."
      },
      %{
        "position" => 3,
        "title" => "Confirm numerically",
        "detail" =>
          "A second pass can confirm the final numeric answer is #{Plan.format_answer(%Plan{final_answer: answer})}."
      }
    ]
  end
end
