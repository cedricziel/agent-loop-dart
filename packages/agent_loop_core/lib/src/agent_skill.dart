class AgentSkill {
  const AgentSkill({
    required this.name,
    required this.description,
    required this.sourceUri,
    this.license,
    this.compatibility,
    this.metadata = const <String, String>{},
  });

  final String name;
  final String description;
  final Uri sourceUri;
  final String? license;
  final String? compatibility;
  final Map<String, String> metadata;
}

class LoadedAgentSkill extends AgentSkill {
  const LoadedAgentSkill({
    required super.name,
    required super.description,
    required super.sourceUri,
    required this.rootUri,
    required this.instructions,
    super.license,
    super.compatibility,
    super.metadata,
  });

  final Uri rootUri;
  final String instructions;
}
