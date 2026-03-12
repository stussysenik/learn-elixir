defmodule LearnElixir.AI.StructuredSolver do
  @moduledoc "Fetches structured math plans from Instructor and falls back to a local solver."

  alias Ecto.Changeset
  alias LearnElixir.AI.FallbackSolver
  alias LearnElixir.Math.Plan
  alias LearnElixir.Math.Verifier

  def solve(problem, conversation) when is_binary(problem) and is_list(conversation) do
    case llm_provider() do
      :instructor ->
        case solve_with_instructor(problem, conversation) do
          {:ok, plan} ->
            attach_verification(plan, :instructor, nil)

          {:error, reason} ->
            solve_with_fallback(problem, reason)
        end

      _ ->
        solve_with_fallback(problem, nil)
    end
  end

  defp solve_with_instructor(problem, conversation) do
    model = Application.get_env(:learn_elixir, :llm_model, "gpt-4o-mini")

    messages =
      [
        %{
          role: "system",
          content: """
          You are a careful math tutor.
          Return a structured arithmetic plan with a normalized expression and concise reasoning steps.
          Only use operators +, -, *, /, parentheses, and ** for exponentiation.
          """
        }
      ] ++
        Enum.take(conversation, -6) ++
        [%{role: "user", content: problem}]

    case Instructor.chat_completion(
           model: model,
           response_model: Plan,
           max_retries: 2,
           messages: messages
         ) do
      {:ok, %Plan{} = plan} -> {:ok, plan}
      {:error, %Changeset{} = changeset} -> {:error, format_changeset(changeset)}
      {:error, reason} -> {:error, reason_to_string(reason)}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp solve_with_fallback(problem, reason) do
    with {:ok, plan} <- FallbackSolver.solve(problem) do
      attach_verification(plan, :fallback, reason)
    end
  end

  defp attach_verification(plan, provider, warning) do
    case Verifier.verify(plan) do
      {:ok, verification} ->
        {:ok,
         %{
           plan: plan,
           provider: provider,
           verification: verification,
           warning: warning
         }}

      {:error, reason} ->
        {:ok,
         %{
           plan: plan,
           provider: provider,
           verification: %{
             status: :unverified,
             expected: nil,
             given: plan.final_answer,
             delta: nil
           },
           warning: warning || Atom.to_string(reason)
         }}
    end
  end

  defp format_changeset(changeset) do
    changeset
    |> Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.map_join("; ", fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
  end

  defp llm_provider do
    Application.get_env(:learn_elixir, :llm_provider, :fallback)
  end

  defp reason_to_string(reason) when is_binary(reason), do: reason
  defp reason_to_string(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp reason_to_string(reason), do: inspect(reason)
end
