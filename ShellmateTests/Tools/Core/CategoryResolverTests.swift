import Testing
import Foundation
@testable import Shellmate

@Suite("CategoryResolver")
struct CategoryResolverTests {

    private let resolver = CategoryResolver()
    private let allCategories = Set(ToolCategory.allCases)

    @Test("calendar keywords match calendar category")
    func calendarKeywords() {
        let result = resolver.resolve(message: "What's on my calendar today?", enabledCategories: allCategories)
        #expect(result.contains(.calendar))
    }

    @Test("file-related messages include files category")
    func filesAlwaysIncluded() {
        let result = resolver.resolve(message: "read my file", enabledCategories: allCategories)
        #expect(result.contains(.files))
    }

    @Test("shell is always included")
    func shellAlwaysIncluded() {
        let result = resolver.resolve(message: "What's the weather?", enabledCategories: allCategories)
        #expect(result.contains(.shell))
    }

    @Test("always includes shell and files when enabled")
    func alwaysIncluded() {
        let result = resolver.resolve(message: "check my schedule", enabledCategories: allCategories)
        #expect(result.contains(.shell))
        #expect(result.contains(.files))
    }

    @Test("falls back to all enabled when no keywords match")
    func fallbackToAll() {
        let result = resolver.resolve(message: "hello how are you", enabledCategories: allCategories)
        #expect(result == allCategories)
    }

    @Test("respects enabled categories filter")
    func respectsEnabledFilter() {
        let enabled: Set<ToolCategory> = [.shell, .files, .calendar]
        let result = resolver.resolve(message: "check my schedule", enabledCategories: enabled)
        #expect(result.contains(.calendar))
        #expect(!result.contains(.reminders))
    }

    @Test("case insensitive matching")
    func caseInsensitive() {
        let result = resolver.resolve(message: "Check my CALENDAR please", enabledCategories: allCategories)
        #expect(result.contains(.calendar))
    }

    @Test("multiple categories can match")
    func multipleCategories() {
        let result = resolver.resolve(message: "remind me about the meeting on my calendar", enabledCategories: allCategories)
        #expect(result.contains(.calendar))
        #expect(result.contains(.reminders))
    }

    @Test("developer keywords match")
    func developerKeywords() {
        let result = resolver.resolve(message: "show me the git log", enabledCategories: allCategories)
        #expect(result.contains(.developer))
    }

    @Test("shell not included if not enabled")
    func shellNotIncludedIfDisabled() {
        let enabled: Set<ToolCategory> = [.calendar]
        let result = resolver.resolve(message: "check my schedule", enabledCategories: enabled)
        #expect(!result.contains(.shell))
        #expect(result.contains(.calendar))
    }

    @Test("fallback only returns enabled categories")
    func fallbackOnlyEnabled() {
        let enabled: Set<ToolCategory> = [.shell, .files]
        let result = resolver.resolve(message: "hello", enabledCategories: enabled)
        #expect(result == enabled)
    }
}
