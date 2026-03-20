# Phase 5: Apps, Developer, Network — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 5 providers (Apps, Process, Web expansion, Developer, Network) with 46 tools total — covering application management, process control, git/SSH/Docker, and network diagnostics. All tools use ShellService for CLI operations.

**Architecture:** All tools are shell-based via `ShellService.run()` or `ShellService.runCommand()`. AppsProvider uses Homebrew/mas. DeveloperProvider wraps git/SSH/Docker CLIs. NetworkProvider wraps standard network utilities. ProcessProvider uses `ps` and `kill`.

**Tech Stack:** Swift 6.0, macOS 14+, Foundation, AppKit (NSWorkspace for app launch), Swift Testing

**Baseline:** 406 tests, Phase 4 complete

---

## File Map

### New Files

| Directory | Files |
|---|---|
| `Shellmate/Services/Tools/Apps/` | AppSearchTool, AppInstallTool, AppCheckInstalledTool, AppUpdateTool, AppUninstallTool, AppListInstalledTool, AppOutdatedTool, AppsProvider |
| `Shellmate/Services/Tools/Process/` | ProcessListTool, ProcessKillTool, AppLaunchTool, AppQuitTool, AppRunningTool, ProcessProvider |
| `Shellmate/Services/Tools/Developer/` | GitStatusTool, GitLogTool, GitDiffTool, GitCommitTool, GitBranchTool, GitPullTool, GitPushTool, GitCloneTool, SSHConnectTool, SSHConfigListTool, DockerPsTool, DockerLogsTool, DockerComposeTool, PortsListeningTool, PortKillTool, EnvListTool, EnvSetTool, DeveloperProvider |
| `Shellmate/Services/Tools/Network/` | NetworkStatusTool, WifiNetworksTool, WifiConnectTool, BluetoothStatusTool, BluetoothToggleTool, NetworkDnsLookupTool, NetworkPingTool, NetworkPortCheckTool, VpnStatusTool, NetworkProvider |
| `ShellmateTests/Tools/` | Apps/AppsToolTests, Process/ProcessToolTests, Developer/DeveloperToolTests, Network/NetworkToolTests |

### Modified Files

| File | Changes |
|---|---|
| `Shellmate/Services/Tools/Web/WebProvider.swift` | Add WebDownloadTool, AppDiscoverTool |
| `Shellmate/Views/Chat/ChatView.swift` | Register 4 new providers (Apps, Process, Developer, Network) |

---

## Task 1: AppsProvider — 7 tools

All tools use Homebrew (`brew`) via ShellService. Tier: search/check/list/outdated are .read, install/update/uninstall are .write.

| Tool | Identifier | Tier | Shell Command |
|---|---|---|---|
| AppSearchTool | app_search | .read | `brew search {query}` |
| AppInstallTool | app_install | .write | `brew install --cask {name}` or `brew install {name}` |
| AppCheckInstalledTool | app_check_installed | .read | `brew list --formula; brew list --cask` |
| AppUpdateTool | app_update | .write | `brew upgrade {name}` |
| AppUninstallTool | app_uninstall | .destructive | `brew uninstall {name}` |
| AppListInstalledTool | app_list_installed | .read | `brew list --formula; brew list --cask` |
| AppOutdatedTool | app_outdated | .read | `brew outdated` |

All take ShellService. Use `run(executable:arguments:)` with structured args where possible. Check if brew is installed first — return helpful message if not.

Tests: conformance, parameter validation, provider has 7 tools.

Commit: `feat: add AppsProvider with 7 Homebrew-based app management tools`

---

## Task 2: ProcessProvider — 5 tools

| Tool | Identifier | Tier | Approach |
|---|---|---|---|
| ProcessListTool | process_list | .read | `ps aux` via shell, params: sort_by, limit, filter |
| ProcessKillTool | process_kill | .destructive | `kill` via shell, params: pid or name. **Check protected process list** |
| AppLaunchTool | app_launch | .write | `open -a "{app}"` via shell |
| AppQuitTool | app_quit | .write | `osascript -e 'tell application "{app}" to quit'` |
| AppRunningTool | app_running | .read | `ps aux | grep -i {name}` |

**Protected processes for ProcessKillTool:** Never kill kernel_task, WindowServer, loginwindow, launchd, SystemUIServer, Dock, Finder. Maintain blocklist.

Tests: conformance, kill rejects protected processes, provider has 5 tools.

Commit: `feat: add ProcessProvider with process list, kill, app launch/quit tools`

---

## Task 3: Expand WebProvider — 2 new tools

| Tool | Identifier | Tier |
|---|---|---|
| WebDownloadTool | web_download | .write |
| AppDiscoverTool | app_discover | .read |

**WebDownloadTool**: params `url`, `destination` (opt), `filename` (opt). Uses `curl -L -o` via ShellService. Shows URL and filename in confirmation.

**AppDiscoverTool**: params `need` (natural language). Uses web_search + brew search to recommend apps. Compound tool — calls ShellService for `brew search`.

Update `WebProvider` to include these 2 new tools (needs ShellService dependency added).

Commit: `feat: add web_download and app_discover to WebProvider`

---

## Task 4: DeveloperProvider — 17 tools

The biggest provider. All shell-based.

### Git tools (8)
| Tool | Identifier | Tier | Command |
|---|---|---|---|
| GitStatusTool | git_status | .read | `git status` |
| GitLogTool | git_log | .read | `git log --oneline -N` |
| GitDiffTool | git_diff | .read | `git diff` |
| GitCommitTool | git_commit | .write | `git add + git commit -m` |
| GitBranchTool | git_branch | .read/.write | `git branch` / `git checkout -b` |
| GitPullTool | git_pull | .write | `git pull` |
| GitPushTool | git_push | .write | `git push` |
| GitCloneTool | git_clone | .write | `git clone {url}` |

All git tools take optional `directory` param for working directory.

### SSH tools (2)
| Tool | Identifier | Tier |
|---|---|---|
| SSHConnectTool | ssh_connect | .write | `ssh {host} {command}` |
| SSHConfigListTool | ssh_config_list | .read | Parse `~/.ssh/config` |

**SECURITY:** Never log or display private key contents. SSHConfigListTool reads config but redacts IdentityFile paths.

### Docker tools (3)
| Tool | Identifier | Tier |
|---|---|---|
| DockerPsTool | docker_ps | .read | `docker ps` |
| DockerLogsTool | docker_logs | .read | `docker logs {container}` |
| DockerComposeTool | docker_compose | .write | `docker compose {subcommand}` |

Check if docker is installed first.

### Port tools (2)
| Tool | Identifier | Tier |
|---|---|---|
| PortsListeningTool | ports_listening | .read | `lsof -iTCP -sTCP:LISTEN -P -n` |
| PortKillTool | port_kill | .destructive | `kill` process on port |

### Environment tools (2)
| Tool | Identifier | Tier |
|---|---|---|
| EnvListTool | env_list | .read | List env vars (redact secrets) |
| EnvSetTool | env_set | .write | Set env var, optionally persist to shell profile |

**SECURITY for EnvSetTool:** Never persist secrets to plain text files. Warn if key looks like a secret.

Tests: conformance for all 17, git_status/log work in the repo, protected port kill, env redaction, provider has 17 tools.

Commit: `feat: add DeveloperProvider with 17 git, SSH, Docker, port, and env tools`

---

## Task 5: NetworkProvider — 9 tools

| Tool | Identifier | Tier | Command |
|---|---|---|---|
| NetworkStatusTool | network_status | .read | `ifconfig`, connectivity check |
| WifiNetworksTool | wifi_networks | .read | `airport -s` scan |
| WifiConnectTool | wifi_connect | .write | `networksetup -setairportnetwork` |
| BluetoothStatusTool | bluetooth_status | .read | `system_profiler SPBluetoothDataType` |
| BluetoothToggleTool | bluetooth_toggle | .write | `blueutil --power` (check if installed) |
| NetworkDnsLookupTool | network_dns_lookup | .read | `dig` or `nslookup` |
| NetworkPingTool | network_ping | .read | `ping -c N {host}` |
| NetworkPortCheckTool | network_port_check | .read | `nc -z -w 3 {host} {port}` |
| VpnStatusTool | vpn_status | .read | `scutil --nc list` |

Tests: conformance, ping localhost works, dns lookup works, provider has 9 tools.

Commit: `feat: add NetworkProvider with 9 network diagnostic and connectivity tools`

---

## Task 6: Register All + Final Verification

- Register AppsProvider, ProcessProvider, DeveloperProvider, NetworkProvider in ChatView
- Update WebProvider registration (now needs ShellService)
- Run full test suite
- Release build
- Tag `phase5-apps-developer-network-complete`
