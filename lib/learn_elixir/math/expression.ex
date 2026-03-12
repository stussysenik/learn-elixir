defmodule LearnElixir.Math.Expression do
  @moduledoc "Normalizes and safely evaluates arithmetic expressions."

  @phrase_replacements [
    {~r/\braised to the power of\b/, "**"},
    {~r/\bto the power of\b/, "**"},
    {~r/\bpower of\b/, "**"},
    {~r/\bmultiplied by\b/, "*"},
    {~r/\btimes\b/, "*"},
    {~r/\bdivided by\b/, "/"},
    {~r/\bover\b/, "/"},
    {~r/\bplus\b/, "+"},
    {~r/\bminus\b/, "-"}
  ]

  @noise_words ~r/\b(what is|calculate|solve|compute|find|answer|please|show me|evaluate)\b/
  @allowed_expression ~r/\A[\d\.\+\-\*\/\(\)\s]+\z/

  def normalize(problem) when is_binary(problem) do
    problem
    |> String.downcase()
    |> String.replace("×", " * ")
    |> String.replace("÷", " / ")
    |> String.replace(~r/(?<=\d)\s*x\s*(?=\d)/, " * ")
    |> replace_phrases()
    |> String.replace(@noise_words, " ")
    |> String.replace(~r/[?=,:;]/, " ")
    |> String.replace(~r/[^0-9\.\+\-\*\/\(\)\s]/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  def evaluate(expression) when is_binary(expression) do
    with {:ok, ast} <- parse(expression),
         {:ok, value} <- eval_ast(ast) do
      {:ok, value * 1.0}
    end
  end

  def evaluate_nx(expression) when is_binary(expression) do
    with {:ok, ast} <- parse(expression),
         {:ok, tensor} <- eval_ast_nx(ast) do
      {:ok, Nx.to_number(tensor) * 1.0}
    end
  end

  def parse(expression) when is_binary(expression) do
    trimmed = String.trim(expression)

    cond do
      trimmed == "" ->
        {:error, :empty_expression}

      not Regex.match?(@allowed_expression, trimmed) ->
        {:error, :unsupported_expression}

      true ->
        case Code.string_to_quoted(trimmed) do
          {:ok, ast} -> {:ok, ast}
          _error -> {:error, :invalid_expression}
        end
    end
  end

  defp replace_phrases(problem) do
    Enum.reduce(@phrase_replacements, problem, fn {pattern, replacement}, acc ->
      Regex.replace(pattern, acc, " #{replacement} ")
    end)
  end

  defp eval_ast(number) when is_integer(number), do: {:ok, number * 1.0}
  defp eval_ast(number) when is_float(number), do: {:ok, number}

  defp eval_ast({:+, _, [value]}), do: eval_ast(value)

  defp eval_ast({:-, _, [value]}) do
    with {:ok, number} <- eval_ast(value) do
      {:ok, -number}
    end
  end

  defp eval_ast({operator, _, [left, right]}) when operator in [:+, :-, :*, :/, :**] do
    with {:ok, left_value} <- eval_ast(left),
         {:ok, right_value} <- eval_ast(right) do
      apply_operator(operator, left_value, right_value)
    end
  end

  defp eval_ast(_ast), do: {:error, :unsupported_expression}

  defp eval_ast_nx(number) when is_integer(number), do: {:ok, Nx.tensor(number * 1.0)}
  defp eval_ast_nx(number) when is_float(number), do: {:ok, Nx.tensor(number)}

  defp eval_ast_nx({:+, _, [value]}), do: eval_ast_nx(value)

  defp eval_ast_nx({:-, _, [value]}) do
    with {:ok, tensor} <- eval_ast_nx(value) do
      {:ok, Nx.negate(tensor)}
    end
  end

  defp eval_ast_nx({operator, _, [left, right]}) when operator in [:+, :-, :*, :/, :**] do
    with {:ok, left_tensor} <- eval_ast_nx(left),
         {:ok, right_tensor} <- eval_ast_nx(right) do
      case operator do
        :+ -> {:ok, Nx.add(left_tensor, right_tensor)}
        :- -> {:ok, Nx.subtract(left_tensor, right_tensor)}
        :* -> {:ok, Nx.multiply(left_tensor, right_tensor)}
        :/ -> {:ok, Nx.divide(left_tensor, right_tensor)}
        :** -> {:ok, Nx.pow(left_tensor, right_tensor)}
      end
    end
  end

  defp eval_ast_nx(_ast), do: {:error, :unsupported_expression}

  defp apply_operator(:+, left_value, right_value), do: {:ok, left_value + right_value}
  defp apply_operator(:-, left_value, right_value), do: {:ok, left_value - right_value}
  defp apply_operator(:*, left_value, right_value), do: {:ok, left_value * right_value}
  defp apply_operator(:**, left_value, right_value), do: {:ok, :math.pow(left_value, right_value)}

  defp apply_operator(:/, _left_value, right_value) when right_value == 0 or right_value == 0.0,
    do: {:error, :division_by_zero}

  defp apply_operator(:/, left_value, right_value), do: {:ok, left_value / right_value}
end
