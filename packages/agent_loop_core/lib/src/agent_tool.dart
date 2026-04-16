import 'agent_types.dart';

typedef JsonSchema = Map<String, Object?>;

class ToolOutput {
  const ToolOutput({
    required this.text,
    this.metadata = const <String, Object?>{},
    this.parts = const <MessagePart>[],
  });

  const ToolOutput.text(
    this.text, {
    this.metadata = const <String, Object?>{},
    this.parts = const <MessagePart>[],
  });

  final String text;
  final Map<String, Object?> metadata;
  final List<MessagePart> parts;
}

class ToolDefinition {
  const ToolDefinition({
    required this.name,
    required this.description,
    this.inputSchema = const <String, Object?>{},
  });

  final String name;
  final String description;
  final JsonSchema inputSchema;
}

abstract interface class AgentTool {
  ToolDefinition get definition;

  Future<ToolOutput> execute(Map<String, Object?> input);
}

class ToolRegistry {
  ToolRegistry(Iterable<AgentTool> tools)
    : _tools = {for (final tool in tools) tool.definition.name: tool};

  final Map<String, AgentTool> _tools;

  List<ToolDefinition> get definitions =>
      _tools.values.map((tool) => tool.definition).toList(growable: false);

  AgentTool? operator [](String name) => _tools[name];
}
