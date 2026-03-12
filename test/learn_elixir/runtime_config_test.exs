defmodule LearnElixir.RuntimeConfigTest do
  use ExUnit.Case, async: true

  alias LearnElixir.RuntimeConfig

  test "merged_env loads .env.local values outside test and lets process env win" do
    env_file =
      Path.join(
        System.tmp_dir!(),
        "learn_elixir-runtime-#{System.unique_integer([:positive])}.env"
      )

    File.write!(
      env_file,
      """
      NVIDIA_NIM_API_KEY=file-key
      OPENAI_MODEL="gpt-file"
      export EXTRA_FLAG=yes
      """
    )

    merged =
      RuntimeConfig.merged_env(
        :dev,
        env_file: env_file,
        system_env: %{"OPENAI_MODEL" => "gpt-shell", "PORT" => "4100"}
      )

    assert merged["NVIDIA_NIM_API_KEY"] == "file-key"
    assert merged["OPENAI_MODEL"] == "gpt-shell"
    assert merged["EXTRA_FLAG"] == "yes"
    assert merged["PORT"] == "4100"

    File.rm(env_file)
  end

  test "merged_env skips .env.local loading in test" do
    env_file =
      Path.join(
        System.tmp_dir!(),
        "learn_elixir-runtime-#{System.unique_integer([:positive])}.env"
      )

    File.write!(env_file, "NVIDIA_NIM_API_KEY=file-key\n")

    merged =
      RuntimeConfig.merged_env(
        :test,
        env_file: env_file,
        system_env: %{"PORT" => "4001"}
      )

    refute Map.has_key?(merged, "NVIDIA_NIM_API_KEY")
    assert merged["PORT"] == "4001"

    File.rm(env_file)
  end

  test "llm_settings prefers NVIDIA NIM over OpenAI" do
    settings =
      RuntimeConfig.llm_settings(%{
        "NVIDIA_NIM_API_KEY" => "nim-key",
        "NVIDIA_NIM_MODEL" => "meta/custom",
        "OPENAI_API_KEY" => "openai-key"
      })

    assert settings.provider == :instructor
    assert settings.provider_label == "Instructor + NVIDIA NIM"
    assert settings.model == "meta/custom"
    assert settings.instructor[:adapter] == Instructor.Adapters.OpenAI

    assert settings.instructor[:openai][:api_url] == "https://integrate.api.nvidia.com"
    assert settings.instructor[:openai][:api_path] == "/v1/chat/completions"
    assert settings.instructor[:openai][:api_key] == "nim-key"
  end

  test "llm_settings falls back when no provider credentials exist" do
    settings = RuntimeConfig.llm_settings(%{})

    assert settings == %{
             provider: :fallback,
             provider_label: "Local deterministic solver"
           }
  end
end
