# agent_loop_provider_ollama

Optional Ollama provider package for `agent_loop` and `agent_loop_core`.

This package keeps Ollama transport code out of the base SDK packages, so applications only install the providers they want to use.

## Features

- Direct HTTP integration with Ollama's `/api/chat` endpoint.
- Optional provider package wiring that still uses the normalized `AgentProvider` contract.
- Streaming support through `AgentStreamingProvider`, with partial assistant output emitted before the final response completes.

## Usage

```dart
import 'package:agent_loop/agent_loop.dart';
import 'package:agent_loop_provider_ollama/agent_loop_provider_ollama.dart';

final sdk = AgentLoopSdk(
  provider: OllamaProvider(
    model: 'llama3.2',
    baseUri: Uri.parse('http://127.0.0.1:11434/'),
    options: const OllamaRequestOptions(temperature: 0.2),
  ),
);
```

Ollama streaming chunks surface through the normal run event stream as ordered `AgentMessagePartEvent` values before the final `AgentAssistantEvent` and `AgentRunCompleteEvent`.
