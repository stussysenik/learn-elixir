defmodule LearnElixir.RuntimeConfig do
  @moduledoc false

  @nim_api_url "https://integrate.api.nvidia.com"
  @nim_api_path "/v1/chat/completions"
  @nim_model "meta/llama-3.1-70b-instruct"
  @openai_model "gpt-4o-mini"

  def merged_env(config_env, opts \\ []) do
    system_env =
      opts
      |> Keyword.get(:system_env, System.get_env())
      |> Map.new()

    env_file = Keyword.get(opts, :env_file)

    if config_env == :test or is_nil(env_file) do
      system_env
    else
      Map.merge(load_env_file(env_file), system_env)
    end
  end

  def llm_settings(env) when is_map(env) do
    cond do
      present?(env["NVIDIA_NIM_API_KEY"]) ->
        %{
          provider: :instructor,
          provider_label: "Instructor + NVIDIA NIM",
          model: Map.get(env, "NVIDIA_NIM_MODEL", @nim_model),
          instructor: [
            adapter: Instructor.Adapters.OpenAI,
            openai: [
              api_url: @nim_api_url,
              api_path: @nim_api_path,
              api_key: env["NVIDIA_NIM_API_KEY"],
              auth_mode: :bearer,
              http_options: [receive_timeout: 60_000]
            ]
          ]
        }

      present?(env["OPENAI_API_KEY"]) ->
        %{
          provider: :instructor,
          provider_label: "Instructor + OpenAI",
          model: Map.get(env, "OPENAI_MODEL", @openai_model),
          instructor: [
            adapter: Instructor.Adapters.OpenAI,
            openai: [api_key: env["OPENAI_API_KEY"]]
          ]
        }

      true ->
        %{
          provider: :fallback,
          provider_label: "Local deterministic solver"
        }
    end
  end

  def load_env_file(path) do
    case File.read(path) do
      {:ok, contents} -> parse_env_file(contents)
      {:error, _reason} -> %{}
    end
  end

  def parse_env_file(contents) when is_binary(contents) do
    contents
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      line
      |> String.trim()
      |> parse_env_line()
      |> case do
        nil -> acc
        {key, value} -> Map.put(acc, key, value)
      end
    end)
  end

  defp parse_env_line(""), do: nil
  defp parse_env_line("#" <> _rest), do: nil

  defp parse_env_line(line) do
    line
    |> String.replace_prefix("export ", "")
    |> String.split("=", parts: 2)
    |> case do
      [key, value] ->
        key = String.trim(key)

        if key == "" do
          nil
        else
          {key, normalize_value(value)}
        end

      _ ->
        nil
    end
  end

  defp normalize_value(value) do
    value
    |> String.trim()
    |> strip_inline_comment()
    |> strip_surrounding_quotes()
  end

  defp strip_inline_comment(value) do
    if quoted?(value) do
      value
    else
      value
      |> String.split(" #", parts: 2)
      |> hd()
      |> String.trim()
    end
  end

  defp strip_surrounding_quotes(value) do
    cond do
      String.length(value) >= 2 and String.starts_with?(value, "\"") and
          String.ends_with?(value, "\"") ->
        value
        |> String.trim_leading("\"")
        |> String.trim_trailing("\"")

      String.length(value) >= 2 and String.starts_with?(value, "'") and
          String.ends_with?(value, "'") ->
        value
        |> String.trim_leading("'")
        |> String.trim_trailing("'")

      true ->
        value
    end
  end

  defp quoted?(<<"\"", _::binary>>), do: true
  defp quoted?(<<"'", _::binary>>), do: true
  defp quoted?(_value), do: false

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
