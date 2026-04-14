# agent_loop_examples

Runnable examples for `agent_loop` that are intended to run on your local machine.

## Local Ollama Loop

Start Ollama and make sure the model you want is available:

```bash
ollama serve
ollama pull gemma4:e4b
```

Run the example with a prompt:

```bash
dart run packages/agent_loop_examples/bin/local_loop.dart "Explain Dart isolates in two sentences."
```

Environment variables:

- `OLLAMA_MODEL`: model name to use. Defaults to `gemma4:e4b`.
- `OLLAMA_BASE_URL`: base URL for the Ollama server. Defaults to `http://127.0.0.1:11434/`.
- `AGENT_LOOP_SYSTEM_PROMPT`: optional system prompt override.

The example currently exposes these local tools to the model:

- `get_time`
- `get_working_directory`
- `list_files`
- `read_file`

If you omit the prompt, the example prints usage help.
