import Foundation

/// Pure functions that generate workspace markdown files from an agent spec.
/// Each generator produces the content for one file in ~/.shellmate/workspace/.
enum GeneratorService {
    /// Generate all workspace files from an agent spec.
    static func generateAll(agent: AgentSpec) -> [GeneratedFile] {
        [
            GeneratedFile(id: "soul", filename: "SOUL.md", content: generateSOUL(agent: agent)),
            GeneratedFile(id: "identity", filename: "IDENTITY.md", content: generateIdentity(agent: agent)),
            GeneratedFile(id: "tools", filename: "TOOLS.md", content: generateTools(agent: agent)),
            GeneratedFile(id: "boundaries", filename: "BOUNDARIES.md", content: generateBoundaries(agent: agent)),
            GeneratedFile(id: "escalation", filename: "ESCALATION.md", content: generateEscalation(agent: agent)),
            GeneratedFile(id: "mac", filename: "MAC.md", content: generateMac(agent: agent)),
            GeneratedFile(id: "memory", filename: "MEMORY.md", content: generateMemory(agent: agent)),
            GeneratedFile(id: "system", filename: "SYSTEM.md", content: generateSystem(agent: agent)),
        ]
    }

    static func generateSOUL(agent: AgentSpec) -> String {
        """
        # \(agent.name) — Soul

        ## Personality
        \(agent.personality)

        ## Mission
        \(agent.mission)

        ## Failure Mode
        \(agent.failure.isEmpty ? "Not specified." : agent.failure)
        """
    }

    static func generateIdentity(agent: AgentSpec) -> String {
        """
        # \(agent.name) — Identity

        You are **\(agent.name)**, a personal AI assistant on macOS.

        \(agent.personality)

        Your mission: \(agent.mission)
        """
    }

    static func generateTools(agent: AgentSpec) -> String {
        """
        # \(agent.name) — Tools

        You have access to the following tools:

        - **shell_exec** — Run terminal commands on the user's Mac
        - **file_read** — Read files from the filesystem
        - **file_write** — Write or create files
        - **file_list** — List directory contents
        - **web_search** — Search the web (Brave Search)
        - **web_fetch** — Fetch and read web pages

        Always explain what you're about to do before using a tool.
        Ask for confirmation before destructive operations.
        """
    }

    static func generateBoundaries(agent: AgentSpec) -> String {
        var content = """
        # \(agent.name) — Boundaries

        ## Never Do These Things
        """
        if agent.never.isEmpty {
            content += "\n- No specific restrictions configured."
        } else {
            for rule in agent.never {
                content += "\n- \(rule)"
            }
        }
        return content
    }

    static func generateEscalation(agent: AgentSpec) -> String {
        """
        # \(agent.name) — Escalation

        ## When Stuck or Uncertain
        \(agent.escalation.isEmpty ? "Ask the user for guidance before proceeding." : agent.escalation)
        """
    }

    static func generateMac(agent: AgentSpec) -> String {
        var content = """
        # \(agent.name) — Mac Integration

        ## Apps the User Works With
        """
        if agent.macApps.isEmpty {
            content += "\nNo specific apps configured."
        } else {
            for app in agent.macApps {
                content += "\n- \(app)"
            }
        }
        content += "\n\n## Use Cases"
        if agent.useCases.isEmpty {
            content += "\nNo specific use cases configured."
        } else {
            for uc in agent.useCases {
                content += "\n- \(uc)"
            }
        }
        return content
    }

    static func generateMemory(agent: AgentSpec) -> String {
        """
        # \(agent.name) — Memory

        ## Core Memory
        This agent uses core memory mode. Important facts about the user
        and their preferences will be retained across conversations.
        """
    }

    static func generateSystem(agent: AgentSpec) -> String {
        """
        # \(agent.name) — System Prompt

        You are \(agent.name). \(agent.personality)

        Your mission: \(agent.mission)

        You are running on macOS. You have access to shell commands, file operations,
        and web tools. Always be helpful, clear, and safe.

        When using tools:
        1. Explain what you're about to do
        2. Ask for confirmation before destructive changes
        3. Show results clearly
        """
    }
}
