# Security Audit Report

**Date:** 2026-03-19
**Branch:** `refactor`
**Baseline commit:** c4f7b07
**Audited by:** 3 parallel security agents (Data & Secrets, Network & Auth, Application & Platform)

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 3 |
| HIGH | 5 |
| MEDIUM | 8 |
| LOW | 7 |
| INFO | 4 |
| **Total** | **27** |

After deduplication (e.g., empty Sparkle key found by all 3 agents), there are **20 unique findings**.

---

## CRITICAL Findings

### C-001: Empty Sparkle EdDSA Public Key — Update Signature Verification Disabled
**Source:** DS-001, NA-001, AP-004 (all 3 agents)
**File:** `Info.plist:21-22`
**Description:** `SUPublicEDKey` is empty. Sparkle cannot verify update signatures. Combined with `SUEnableAutomaticChecks=true` and `SUAllowsAutomaticUpdates=true`, a MITM attacker on the update feed could push a malicious binary to all users silently.
**Fix:** Generate EdDSA key pair with Sparkle's `generate_keys` tool. Populate the public key. Until then, disable automatic updates.
**Remediation:** ✅ Fixed (2026-03-20) — EdDSA key pair generated via Sparkle `generate_keys`. Public key set in Info.plist, private key stored in GitHub Actions secret. Auto-update checks enabled.

### C-002: Shell Command Execution With No Security Check or User Approval
**Source:** AP-002, AP-008
**File:** `Services/Tools/ShellTool.swift:11-31`, `Services/Tools/ToolExecutor.swift:16-38`
**Description:** `ShellTool` passes AI-provided commands directly to `/bin/zsh -c` without any validation, blocklist check, or user confirmation. Unlike file tools, the shell tool bypasses `SecurityPolicy` entirely. This is the primary vector for prompt injection exploitation.
**Fix:** Add shell command blocklist in SecurityPolicy and log commands clearly for user review. Full user-approval dialogs are a feature decision.
**Remediation:** ✅ Fixed — shell command blocklist added with dangerous pattern detection.

### C-003: App Sandbox Disabled
**Source:** AP-001, NA-010
**File:** `Resources/Shellmate.entitlements:6`
**Description:** `com.apple.security.app-sandbox` is `false`. The app has unrestricted access to the filesystem, processes, and network. This is intentional — the app requires shell execution and arbitrary file access as core features.
**Remediation:** ⏭️ Accepted risk — sandboxing is incompatible with the core feature set (shell execution, arbitrary file R/W). Documented in KNOWN_ISSUES with rationale.

---

## HIGH Findings

### H-001: SecurityPolicy Path Blocklist Bypassed Via Symlinks and Missing Paths
**Source:** AP-003, AP-006
**File:** `Services/Tools/SecurityPolicy.swift:19-38`
**Description:** `isPathBlocked` uses `URL.standardized` which does NOT resolve symlinks. Missing from blocklist: `Library/LaunchAgents`, `Library/LaunchDaemons`, `.zshrc`, `.bashrc`, `.bash_profile`, `.zprofile`, `.docker/config.json`, `.netrc`, `.npmrc`, `.config/gh/hosts.yml`.
**Fix:** Use `resolvingSymlinksInPath()` and expand the blocklist.
**Remediation:** ✅ Fixed

### H-002: SSRF — WebFetchTool Follows Redirects to Blocked URLs
**Source:** NA-002, NA-009, AP-005
**File:** `Services/Tools/WebFetchTool.swift:32`, `Services/Tools/SecurityPolicy.swift:42-76`
**Description:** URLSession follows redirects by default. SSRF check only validates the initial URL. A redirect to `127.0.0.1` or `169.254.169.254` bypasses the filter.
**Fix:** Use a custom URLSessionDelegate that validates redirect targets against SecurityPolicy.
**Remediation:** ✅ Fixed

### H-003: SSRF Filter Missing IPv6, Octal, Hex, Decimal IP Formats
**Source:** NA-003, AP-007
**File:** `Services/Tools/SecurityPolicy.swift:64-76`
**Description:** `isPrivateIP` only matches dotted-decimal IPv4. Missing: IPv6 private addresses, IPv4-mapped IPv6, octal/hex/decimal IP encodings.
**Fix:** Parse host with `inet_pton` and check binary address against RFC 1918 ranges.
**Remediation:** ✅ Fixed (expanded IP validation with inet_pton)

### H-004: FileWriteTool Can Write to Sensitive Locations (LaunchAgents, Shell Configs)
**Source:** AP-006
**File:** `Services/Tools/FileWriteTool.swift:21-24`
**Description:** `FileWriteTool` creates arbitrary directories and writes to any non-blocked path. Can write to `~/Library/LaunchAgents/` or `~/.zshrc` for persistent code execution.
**Fix:** Expand SecurityPolicy blocklist to include these paths.
**Remediation:** ✅ Fixed (merged into H-001 blocklist expansion)

### H-005: API Key Validation Skipped on Save in Setup Views
**Source:** DS-002
**File:** `Views/Setup/AISetupView.swift`, `Views/Setup/SimpleAISetup.swift`
**Description:** Setup views save API keys directly to Keychain and set `isConfigured=true` without validating through `AIRouter.validateApiKey()`.
**Fix:** Route through `AIConfigState.saveAndValidateKey()`.
**Remediation:** ✅ Fixed

---

## MEDIUM Findings

### M-001: Chat History Persisted Without Restrictive File Permissions
**Source:** DS-003
**File:** `State/ChatState.swift:46-57`
**Description:** `chat-history.json` written with default permissions (0o644) instead of 0o600.
**Remediation:** ✅ Fixed

### M-002: Wizard Progress Persisted Without Restrictive File Permissions
**Source:** DS-004
**File:** `State/WizardState.swift:88-98`
**Description:** `wizard-progress.json` written with default permissions.
**Remediation:** ✅ Fixed

### M-003: Workspace Files Written Without Restrictive Permissions
**Source:** DS-005
**File:** `Services/WorkspaceService.swift:46`
**Description:** Workspace files lack explicit 0o600 permissions.
**Remediation:** ✅ Fixed

### M-004: WebFetchTool Allows HTTP (Non-HTTPS) Fetches
**Source:** NA-004
**File:** `Services/Tools/SecurityPolicy.swift:50`
**Description:** Plaintext HTTP allowed, enabling MITM-based content tampering and prompt injection.
**Remediation:** 📋 Tracked — HTTPS-only would break legitimate use cases (many sites still serve HTTP). Warning logged instead.

### M-005: API Error Responses Logged Verbatim
**Source:** NA-005
**File:** `Services/AI/AnthropicClient.swift:38,47-48`, `Services/AI/OpenAIClient.swift:36,43-44`
**Description:** Full API error body forwarded to error messages and logs.
**Remediation:** ✅ Fixed (truncated to 500 chars)

### M-006: Brave Search API Key Read Only From Environment Variable
**Source:** NA-006
**File:** `Services/Tools/WebSearchTool.swift:14`
**Description:** Brave API key not stored in Keychain like Anthropic/OpenAI keys.
**Remediation:** 📋 Tracked — env var is the documented setup pattern for Brave; low impact.

### M-007: No Certificate Pinning for API Endpoints
**Source:** NA-007
**File:** `Services/AI/AnthropicClient.swift:32`, `Services/AI/OpenAIClient.swift:31`
**Description:** No certificate pinning. Default system TLS validation only.
**Remediation:** 📋 Tracked — certificate pinning adds operational complexity (pin rotation) and is typically overkill for desktop apps. Low risk with HTTPS.

### M-008: OAuth Token Stored Without Refresh/Rotation Mechanism
**Source:** NA-008
**File:** `Utilities/KeychainHelper.swift:106-129`
**Description:** No refresh token flow. Expired tokens require manual re-auth.
**Remediation:** 📋 Tracked — full OAuth flow deferred per KNOWN_ISSUES.

---

## LOW Findings

### L-001: API Key Held as Immutable String in Memory
**Source:** DS-006
**File:** `State/AIConfigState.swift:84-99`
**Remediation:** ⏭️ Accepted risk — impractical to mitigate in Swift.

### L-002: Clipboard Copy Without Timeout for Sensitive Content
**Source:** DS-007
**File:** `Views/Chat/MessageBubble.swift`
**Remediation:** 📋 Tracked

### L-003: Backup Config Files Not Permission-Restricted
**Source:** DS-008
**File:** `Services/ConfigService.swift:86-89`
**Remediation:** ✅ Fixed

### L-004: Keychain Items Not Cleaned Up on Reset
**Source:** DS-010
**File:** `Utilities/KeychainHelper.swift`
**Remediation:** ✅ Fixed — added `deleteAllKeys()` method.

### L-005: Keychain Items Accessible to Other Same-User Processes
**Source:** NA-012, AP-015
**File:** `Utilities/KeychainHelper.swift:24-30`
**Remediation:** ⏭️ Accepted risk — app is unsandboxed by design.

### L-006: Shell Command Logged in Cleartext
**Source:** AP-010
**File:** `Services/Tools/ShellTool.swift:18`
**Remediation:** ✅ Fixed (log only command length, not content)

### L-007: No Input Length Limits on User Text
**Source:** AP-011
**File:** `Views/Chat/ChatView.swift`
**Remediation:** 📋 Tracked

---

## INFO Findings

### I-001: Test Files Contain Synthetic API Key Patterns
**Source:** DS-009
**Description:** Expected for unit tests, not real credentials.
**Remediation:** No action needed.

### I-002: All Network Communication Uses HTTPS for Known Endpoints
**Source:** NA-013
**Description:** Positive finding — verified correct.

### I-003: API Keys Never Stored in UserDefaults or Files
**Source:** NA-014
**Description:** Positive finding — Keychain-only storage verified.

### I-004: No Privacy Usage Descriptions Needed Currently
**Source:** AP-012
**Description:** No TCC-protected APIs used directly.

---

## Remediation Summary

| Status | Count |
|--------|-------|
| ✅ Fixed | 12 |
| 📋 Tracked in KNOWN_ISSUES | 5 |
| ⏭️ Accepted risk | 3 |
| No action needed | 4 |
