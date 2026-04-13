## ADDED Requirements

### Requirement: SDK stores transcript content as ordered message parts
The SDK SHALL allow transcript messages to contain an ordered collection of typed message parts so assistant, user, and tool activity can be represented without collapsing all output into a single string.

#### Scenario: Assistant response includes multiple part types
- **WHEN** a provider response includes text plus additional structured output such as reasoning or file references
- **THEN** the SDK stores those values as separate ordered parts within the same transcript message

#### Scenario: Text-only callers remain supported
- **WHEN** a caller continues using a text-only prompt and response flow
- **THEN** the SDK still produces transcript messages whose canonical content can be represented entirely with text parts

### Requirement: SDK represents file attachments as transcript parts
The SDK SHALL represent generated or referenced files as structured file parts that can survive event streaming and session resume without embedding binary file contents in the transcript.

#### Scenario: Tool result references a generated file
- **WHEN** a tool or provider output includes a file attachment or file reference
- **THEN** the transcript records a file part with reference metadata needed for downstream rendering and resume

#### Scenario: Session resume preserves file references
- **WHEN** a caller resumes a conversation that already contains file parts
- **THEN** the resumed transcript includes the original file part metadata in the same logical order
