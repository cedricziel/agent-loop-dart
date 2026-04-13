typedef JsonSchema = Map<String, Object?>;

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

  Future<String> execute(Map<String, Object?> input);
}

class ToolRegistry {
  ToolRegistry(Iterable<AgentTool> tools)
    : _tools = {for (final tool in tools) tool.definition.name: tool};

  final Map<String, AgentTool> _tools;

  List<ToolDefinition> get definitions =>
      _tools.values.map((tool) => tool.definition).toList(growable: false);

  AgentTool? operator [](String name) => _tools[name];
}
