# Test Coverage Report

## Summary

**Total tests:** 165
**Total suites:** 32
**Framework:** Swift Testing (`import Testing`, `@Test`, `#expect`, `@Suite`)
**All tests pass:** Yes (`swift test` exits 0)

## Tests Per Module

| Module | Suite | Tests | File |
|--------|-------|-------|------|
| **Models** | ChatMessage | 6 | `ChatMessageTests.swift` |
| | JSONValue | 12 | `JSONValueTests.swift` |
| | AgentSpec | 3 | `AgentSpecTests.swift` |
| | ShellmateConfig | 4 | `ShellmateConfigTests.swift` |
| | ToolDefinition | 5 | `ToolDefinitionTests.swift` |
| **Services** | GeneratorService | 16 | `GeneratorServiceTests.swift` |
| | ConfigService | 2 | `ConfigServiceTests.swift` |
| | MigrationService | 3 | `MigrationServiceTests.swift` |
| | WorkspaceService | 3 | `WorkspaceServiceTests.swift` |
| | ValidationService | 4 | `ValidationServiceTests.swift` |
| **AI Clients** | AIRouter | 5 | `AIRouterTests.swift` |
| **Tools** | SecurityPolicy | 5 | `SecurityPolicyTests.swift` |
| | SecurityPolicy (extended) | 7 | `SecurityPolicyExtendedTests.swift` |
| | ShellTool | 6 | `ShellToolTests.swift` |
| | FileReadTool | 5 | `FileToolTests.swift` |
| | FileWriteTool | 4 | `FileToolTests.swift` |
| | FileListTool | 5 | `FileToolTests.swift` |
| | WebSearchTool | 2 | `WebToolTests.swift` |
| | WebFetchTool | 4 | `WebToolTests.swift` |
| | ToolExecutor | 3 | `ToolExecutorTests.swift` |
| **Test Infra** | TestFixtures | — | `TestFixtures.swift` |

## Key Tested Paths

### Models
- All Codable round-trips (encode -> decode -> verify equality)
- JSONValue: all 7 type cases, nested structures, accessors, anyValue interop
- AgentSpec: snake_case CodingKeys mapping
- ShellmateConfig: nested structure, ToolPermissions, CapabilitiesConfig
- ToolDefinition: schemas, provider format conversion (Anthropic + OpenAI), deny filtering

### Services
- GeneratorService: all 8 generators produce non-empty content, contain expected agent data, handle empty specs with fallbacks
- ConfigService: config round-trip encoding
- ValidationService: all check types return valid structures
- MigrationService: needs-migration detection logic, copy-and-rename behavior
- WorkspaceService: path resolution, file existence checks

### Tools
- SecurityPolicy: 12 tests covering path blocklist (home-relative + absolute), URL blocklist (private IPs, localhost, non-HTTP schemes, malformed), dot-dot path resolution
- ShellTool: echo, pwd, exit codes, stderr capture, empty output, timeout termination
- FileReadTool: read success, nonexistent, missing params, blocked path, oversized file
- FileWriteTool: write success, parent directory creation, missing params, blocked path
- FileListTool: directory listing, empty dir, blocked path, depth limiting, directory trailing slash
- WebSearchTool: missing query, missing API key
- WebFetchTool: missing URL, localhost blocking, private IP blocking, scheme blocking
- ToolExecutor: routing to correct tool, unknown tool error

### AI Clients
- Provider detection, model normalization, OAuth token detection
- Tool deny category mapping and filtering

## Known Test Gaps (TODOs)

- **ConfigService isolated tests:** ConfigService init does not accept a custom directory, so read/write/backup cannot be tested in isolation without touching `~/.shellmate/`. TODO: Add `configDir:` parameter to ConfigService init.
- **AnthropicClient/OpenAIClient request building:** Not tested (would require mocking URLSession or extracting request-building into testable functions). TODO: Extract `buildRequest` as internal and test headers/body structure.
- **AnthropicClient/OpenAIClient response parsing:** Not tested end-to-end. TODO: Extract `parseResponse` as internal and test with sample JSON payloads.
- **Streaming (SSE) parsing:** Not tested. TODO: Test line-by-line SSE parsing with mock data.
- **ToolUseLoop:** Not tested (requires mocking AI responses and tool execution). TODO: Create mock AIRouter and ToolExecutor for integration testing.
- **AIConfigState.resolveApiKey:** Not tested (depends on Keychain and environment). TODO: Test with mock KeychainHelper.
- **ChatState, WizardState, AppState:** Observable state classes not tested (UI-coupled). TODO: Test state transitions and phase navigation.
- **View layer:** No view tests. Would require ViewInspector or similar. Low priority for now.
- **WebFetchTool HTML extraction:** Not tested with real HTML content. TODO: Test `extractText` with sample HTML documents.
- **Shell command output truncation:** Not tested (would need a command that produces >100K chars). TODO: Test with `yes | head -c 200000` or similar.
