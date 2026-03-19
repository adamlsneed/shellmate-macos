import Foundation

enum GeneratorService {
    static func generateAll(agent: AgentSpec, capabilities: CapabilitiesConfig? = nil) -> [GeneratedFile] {
        [
            GeneratedFile(id: "soul", filename: "SOUL.md", content: generateSOUL(agent: agent)),
            GeneratedFile(id: "agents", filename: "AGENTS.md", content: generateAgents(agent: agent)),
            GeneratedFile(id: "identity", filename: "IDENTITY.md", content: generateIdentity(agent: agent)),
            GeneratedFile(id: "user", filename: "USER.md", content: generateUser(agent: agent)),
            GeneratedFile(id: "tools", filename: "TOOLS.md", content: generateTools(agent: agent)),
            GeneratedFile(id: "bootstrap", filename: "BOOTSTRAP.md", content: generateBootstrap(agent: agent)),
            GeneratedFile(id: "memory", filename: "MEMORY.md", content: generateMemory(agent: agent)),
            GeneratedFile(id: "memory-readme", filename: "memory/README.md", content: generateMemoryReadme()),
            GeneratedFile(id: "skills-readme", filename: "skills/README.md", content: generateSkillsReadme(agent: agent, capabilities: capabilities)),
        ]
    }

    static func generateSOUL(agent: AgentSpec) -> String {
        let neverRules = agent.never.isEmpty ? "- // TODO: define hard rules" : agent.never.map { "- **NEVER** \($0)" }.joined(separator: "\n")
        let personalitySection = agent.personality.isEmpty ? "" : "## Personality\n\n\(agent.personality)\n\n"
        let useCasesSection: String
        if agent.useCases.isEmpty { useCasesSection = "" }
        else { useCasesSection = "## What I Help With\n\n\(agent.useCases.map { "- \($0)" }.joined(separator: "\n"))\n\n" }
        let failureLine = agent.failure.isEmpty ? "// TODO: what to do when things go wrong" : agent.failure
        let escalationLine = agent.escalation.isEmpty ? "// TODO: escalation rules" : "Escalation: \(agent.escalation)"
        let name = agent.name.isEmpty ? "Shellmate" : agent.name
        let mission = agent.mission.isEmpty ? "// TODO: mission not specified" : agent.mission
        let missionBody = agent.mission.isEmpty ? "// TODO: describe what you do and why it matters" : agent.mission
        return "# SOUL.md \u{2014} Who I Am\n\nI'm **\(name)** \u{2014} \(mission)\n\n## Purpose\n\n\(missionBody)\n\n\(personalitySection)\(useCasesSection)## Behavioral Guidelines\n\n- Skip the \"Great question!\" \u{2014} just help.\n- Be bold internally, cautious externally.\n- If unsure, say so. Don't hallucinate facts.\n- You're a Mac-native helper \u{2014} think in terms of apps, Shortcuts, and local workflows.\n- \(failureLine)\n- \(escalationLine)\n\n## Hard Rules\n\n\(neverRules)\n\n---\n\n_Update this file as you evolve. This is your north star._\n"
    }

    static func generateIdentity(agent: AgentSpec) -> String {
        let name = agent.name.isEmpty ? "Shellmate" : agent.name
        let roleShort: String
        if agent.mission.isEmpty { roleShort = "// TODO" }
        else { roleShort = String((agent.mission.split(separator: ".").first.map(String.init) ?? agent.mission).prefix(80)) }
        let personalityLine: String
        if agent.personality.isEmpty { personalityLine = "// TODO" }
        else { personalityLine = String((agent.personality.split(separator: ".").first.map(String.init) ?? agent.personality).prefix(80)) }
        return "# IDENTITY.md \u{2014} Who Am I?\n\n- **Name:** \(name)\n- **Platform:** Shellmate (Mac desktop assistant)\n- **Role:** \(roleShort)\n- **Personality:** \(personalityLine)\n- **Vibe:** // TODO\n- **Emoji:** // TODO\n- **Avatar:** // TODO\n"
    }

    static func generateTools(agent: AgentSpec) -> String {
        let macApps = agent.macApps.isEmpty ? "// TODO: List the Mac apps you use regularly" : agent.macApps.map { "- \($0)" }.joined(separator: "\n")
        return "# TOOLS.md \u{2014} Mac Environment Notes\n\nSkills define how your tools work. This file is for **your specifics** \u{2014} the apps, paths, and quirks of your Mac setup.\n\n## Mac Apps\n\n\(macApps)\n\n## Shortcuts\n\n// TODO: List Apple Shortcuts and what they do\n\n## Finder Paths\n\n// TODO: Key folders and their purposes\n\n## Automation Notes\n\n// TODO: Any Automator workflows, cron jobs, or launchd agents\n\n## Other Environment Notes\n\n// TODO: API key locations, local paths, service URLs, etc.\n"
    }

    static func generateAgents(agent: AgentSpec) -> String {
        let neverRules = agent.never.isEmpty ? "- // TODO: define red lines" : agent.never.map { "- **NEVER** \($0)" }.joined(separator: "\n")
        let escalation = agent.escalation.isEmpty ? "// TODO: define escalation rules" : agent.escalation
        let failure = agent.failure.isEmpty ? "// TODO: define failure behavior" : agent.failure
        return "# AGENTS.md \u{2014} Operating Rules\n\n## Session Startup\n\n1. Read `SOUL.md` \u{2014} who you are\n2. Read `USER.md` \u{2014} who you're helping\n3. Read `MEMORY.md` \u{2014} your curated long-term memory\n4. Read `memory/YYYY-MM-DD.md` (today + yesterday) for recent context\n5. Check your task queue\n\n## Memory Architecture\n\n- **Daily logs:** `memory/YYYY-MM-DD.md` \u{2014} write today's context here\n- **Curated memory:** `MEMORY.md` \u{2014} the distilled version, updated periodically\n- If you want to remember something, **write it to a file**\n\n## Red Lines\n\n\(neverRules)\n\n## Escalation Rules\n\n\(escalation)\n\n## Failure Behavior\n\n\(failure)\n\n## Safety Boundaries\n\n**Safe actions (no permission needed):**\n- Reading files in your workspace\n- Web searches and lookups\n- Internal organization and memory updates\n- Reading Mac app state and preferences\n\n**Needs permission:**\n- Sending emails or public posts\n- Running Shortcuts that affect external systems\n- Modifying files outside your workspace\n- Actions that affect other apps or system settings\n\n## Confirmation Required\n\nBefore running any of these actions, ALWAYS ask the user first in plain language:\n- Deleting or moving files\n- Changing system settings (System Preferences / System Settings)\n- Installing or uninstalling software\n- Modifying login items or startup programs\n- Accessing contacts, messages, or other personal data\n- Running commands with sudo or admin privileges\n- Sending emails or messages on behalf of the user\n\nFrame it simply: \"I can [action] for you. Should I go ahead?\"\nNever proceed with these actions without explicit confirmation.\n"
    }

    static func generateUser(agent: AgentSpec) -> String {
        let macAppsSection: String
        if agent.macApps.isEmpty { macAppsSection = "## Mac Apps & Preferences\n\n// TODO: Which apps do they use most? Any preferences or workflows?" }
        else { macAppsSection = "## Mac Apps & Preferences\n\n\(agent.macApps.map { "- **\($0):** // TODO: how they use it, preferences, quirks" }.joined(separator: "\n"))" }
        return "# USER.md \u{2014} About Your Human\n\n- **Name:** // TODO\n- **What to call them:** // TODO\n- **Pronouns:** // TODO\n- **Timezone:** // TODO\n\n## Context\n\n// TODO: Learn about the person you're helping. Update this as you go.\n\n- **Interests:** // TODO\n- **Values:** // TODO\n- **Active projects:** // TODO\n- **Frustrations:** // TODO\n- **Humor:** // TODO\n\n\(macAppsSection)\n\n## Notes\n\n// TODO: Anything else that helps you be more helpful\n"
    }

    static func generateBootstrap(agent: AgentSpec) -> String {
        let name = agent.name.isEmpty ? "Shellmate" : agent.name
        return "# BOOTSTRAP.md \u{2014} First Run\n\nHey. You're new here \u{2014} welcome to Shellmate.\n\nWe've already prepared your identity files, so start by reading them:\n\n1. Read `SOUL.md` \u{2014} your identity and purpose\n2. Read `IDENTITY.md` \u{2014} your name, vibe, and emoji\n3. Read `USER.md` \u{2014} who you're helping\n4. Read `MEMORY.md` \u{2014} long-term memory (probably empty)\n\n## The Four Things to Discover\n\n- **Name:** You're **\(name)**. Does it fit?\n- **Nature:** What kind of Mac helper are you? Casual assistant? Power-user copilot? Something else?\n- **Vibe:** How do you communicate? Formal? Casual? Terse? Playful?\n- **Emoji:** Pick one that represents you.\n\n## What to Do Next\n\n- Talk to your human. Learn about them and their Mac workflow.\n- Update `IDENTITY.md` with anything you discover about yourself.\n- Update `USER.md` with what you learn about them.\n- Check out `TOOLS.md` and fill in their Mac environment details.\n- Start building your memory \u{2014} write things down.\n\n---\n\n_Delete this file after your first run. You won't need it again._\n"
    }

    static func generateMemory(agent: AgentSpec) -> String {
        let name = agent.name.isEmpty ? "Shellmate" : agent.name
        let mission = agent.mission.isEmpty ? "// TODO" : agent.mission
        return "# MEMORY.md - Long-Term Memory\n\n## Role\n\n**\(name)** \u{2014} \(mission)\n\n## Goal\n\n// TODO: Add long-term goals and current priorities\n\n## Active Context\n\n// TODO: What are you currently working on?\n\n## Key Decisions\n\n// TODO: Important decisions made so far\n\n## Lessons Learned\n\n// TODO: What have you learned that future-you should know?\n\n---\n\n_Update this file during sessions. This is your curated long-term memory._\n"
    }

    static func generateMemoryReadme() -> String {
        "# memory/ - Session Logs\n\n## Naming Convention\n\n`YYYY-MM-DD.md` \u{2014} one file per day.\n\n## What to Log\n\n- Tasks completed\n- Decisions made and why\n- Context that will be useful next session\n- Errors encountered and how they were resolved\n- Links, IDs, and references for ongoing work\n\n## What NOT to Log\n\n- Sensitive credentials (use environment variables)\n- Redundant info already in SOUL.md or AGENTS.md\n\n---\n\n_These are raw daily notes. Distill important learnings into MEMORY.md periodically._\n"
    }

    static func generateSkillsReadme(agent: AgentSpec, capabilities: CapabilitiesConfig? = nil) -> String {
        let name = agent.name.isEmpty ? agent.id : agent.name
        let installLines: String
        if let skills = capabilities?.recommendedSkills, !skills.isEmpty {
            installLines = skills.map { "# \($0)\nclawhub install \($0)" }.joined(separator: "\n\n")
        } else { installLines = "# Add workspace-local skills here\n# clawhub install <skill-id>" }
        return "# Workspace Skills \u{2014} \(name)\n\nSkills placed in this folder are **local to this agent only** and override any global skill with the same name.\n\n## How to install a skill into this workspace\n\n```bash\n# From inside this workspace directory:\nclawhub install <skill-id>\n\n# Or specify the workspace explicitly:\nclawhub install <skill-id> --workdir ~/.shellmate/workspace\n```\n\n## Recommended skills for this agent\n\n\(installLines)\n\n## Notes\n\n- Skills here take precedence over bundled and managed (~/.shellmate/skills) skills of the same name.\n- After installing, restart Shellmate (or start a new session) for the skill to take effect.\n- Browse all available skills at https://clawhub.ai\n"
    }
}
