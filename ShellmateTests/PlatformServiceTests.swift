import Testing
import Foundation
@testable import Shellmate

@Suite("Platform Services")
struct PlatformServiceTests {

    // MARK: - ExternalLinkHandler

    @Suite("ExternalLinkHandler")
    struct ExternalLinkHandlerTests {

        @Test("rejects invalid URL strings")
        func testInvalidURL() {
            let result = ExternalLinkHandler.open("")
            #expect(result == false)
        }

        @Test("rejects non-http/https/mailto schemes")
        func testBlockedSchemes() {
            #expect(ExternalLinkHandler.open(URL(string: "file:///etc/passwd")!) == false)
            #expect(ExternalLinkHandler.open(URL(string: "ftp://example.com")!) == false)
        }

        @Test("URL scheme validation for allowed schemes")
        func testAllowedSchemes() {
            // Verify URL parsing works for valid schemes
            // (Cannot call open() in tests without actually launching a browser)
            let https = URL(string: "https://example.com")!
            #expect(https.scheme == "https")

            let http = URL(string: "http://example.com")!
            #expect(http.scheme == "http")

            let mailto = URL(string: "mailto:test@example.com")!
            #expect(mailto.scheme == "mailto")
        }
    }

    // MARK: - Notification Names

    @Suite("Notification Names")
    struct NotificationNameTests {

        @Test("shellmateWillTerminate has correct raw value")
        func testTerminateNotification() {
            #expect(Notification.Name.shellmateWillTerminate.rawValue == "shellmateWillTerminate")
        }

        @Test("shellmateNewChat has correct raw value")
        func testNewChatNotification() {
            #expect(Notification.Name.shellmateNewChat.rawValue == "shellmateNewChat")
        }

        @Test("shellmateClearChat has correct raw value")
        func testClearChatNotification() {
            #expect(Notification.Name.shellmateClearChat.rawValue == "shellmateClearChat")
        }

        @Test("notifications post and observe synchronously")
        func testNotificationRoundTrip() {
            var received = false

            let observer = NotificationCenter.default.addObserver(
                forName: .shellmateNewChat,
                object: nil,
                queue: nil
            ) { _ in
                received = true
            }

            NotificationCenter.default.post(name: .shellmateNewChat, object: nil)

            #expect(received == true)
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Platform Security

    @Suite("Platform Security")
    struct PlatformSecurityTests {

        @Test("shellmate config path is not blocked by security policy")
        func testShellmatePathAllowed() {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let shellmatePath = "\(home)/.shellmate/shellmate.json"
            #expect(!SecurityPolicy.isPathBlocked(shellmatePath))
        }

        @Test("AI API URLs are not blocked by security policy")
        func testAPIURLsAllowed() {
            #expect(!SecurityPolicy.isURLBlocked("https://api.anthropic.com/v1/messages"))
            #expect(!SecurityPolicy.isURLBlocked("https://api.openai.com/v1/chat/completions"))
            #expect(!SecurityPolicy.isURLBlocked("https://api.search.brave.com/res/v1/web/search"))
        }

        @Test("Sparkle update URL is not blocked by security policy")
        func testSparkleURLAllowed() {
            #expect(!SecurityPolicy.isURLBlocked("https://github.com/adamlsneed/shellmate-macos/releases/latest/download/appcast.xml"))
        }
    }

    // MARK: - App Lifecycle

    @Suite("AppLifecycle")
    struct AppLifecycleTests {

        @Test("AppLifecycleManager can be instantiated")
        func testLifecycleManagerInit() {
            let manager = AppLifecycleManager()
            #expect(manager is NSObject)
        }
    }
}
