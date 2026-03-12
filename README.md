# LearnElixir

A Phoenix LiveView lab for supervised reasoning agents.

The app ships with:

- A stateful `GenServer` brain per shared room
- `DynamicSupervisor` restart protection
- LiveView transcript streaming with `stream_insert/4`
- `Phoenix.Presence` tracking for active agents
- `Phoenix.PubSub` room broadcasts
- `Instructor` support for structured LLM output when NVIDIA NIM or OpenAI credentials are configured
- `Nx` verification for every numeric answer

## Run it

1. Install dependencies with `mix setup`
2. Optionally add `NVIDIA_NIM_API_KEY` to `.env.local` or export it in your shell
3. Optionally set `NVIDIA_NIM_MODEL` if you want something other than `meta/llama-3.1-70b-instruct`
4. OpenAI still works with `OPENAI_API_KEY` and `OPENAI_MODEL`, but NIM takes precedence when both are present
5. Start the server with `mix phx.server`
6. Open [`http://localhost:4000`](http://localhost:4000)

Without an API key, the app uses a deterministic local arithmetic solver and still verifies results with Nx.

## Checks

- `mix test`
- `mix precommit`
