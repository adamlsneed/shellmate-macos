import Foundation
import Testing
@testable import Shellmate

@Suite("Provider Detection and Model Normalization")
struct ProviderDetectionTests {

    @Test("detects anthropic from various model strings")
    func testDetectAnthropic() {
        #expect(detectProvider(model: "claude-sonnet-4-20250514") == .anthropic)
        #expect(detectProvider(model: "claude-3-haiku") == .anthropic)
        #expect(detectProvider(model: "claude-3-opus") == .anthropic)
        #expect(detectProvider(model: "Claude-Sonnet-4") == .anthropic)
        #expect(detectProvider(model: "anthropic/claude-3-haiku") == .anthropic)
    }

    @Test("detects openai from various model strings")
    func testDetectOpenAI() {
        #expect(detectProvider(model: "gpt-4o") == .openai)
        #expect(detectProvider(model: "gpt-4o-mini") == .openai)
        #expect(detectProvider(model: "GPT-4") == .openai)
        #expect(detectProvider(model: "o1-preview") == .openai)
        #expect(detectProvider(model: "o3-mini") == .openai)
        #expect(detectProvider(model: "o4-mini") == .openai)
    }

    @Test("defaults to anthropic for unknown models")
    func testDetectDefault() {
        #expect(detectProvider(model: "unknown-model") == .anthropic)
        #expect(detectProvider(model: "llama-3") == .anthropic)
    }

    @Test("normalizes model strings with provider prefix")
    func testNormalizeModel() {
        #expect(normalizeModel("anthropic/claude-sonnet-4-20250514") == "claude-sonnet-4-20250514")
        #expect(normalizeModel("openai/gpt-4o") == "gpt-4o")
        #expect(normalizeModel("Anthropic/claude-3-haiku") == "claude-3-haiku")
        #expect(normalizeModel("OpenAI/gpt-4o-mini") == "gpt-4o-mini")
    }

    @Test("normalizeModel preserves model without prefix")
    func testNormalizeModelNoPrefix() {
        #expect(normalizeModel("claude-sonnet-4-20250514") == "claude-sonnet-4-20250514")
        #expect(normalizeModel("gpt-4o") == "gpt-4o")
    }

    @Test("detects OAuth tokens")
    func testIsOAuthToken() {
        #expect(isOAuthToken("sk-ant-oat-abc123") == true)
        #expect(isOAuthToken("sk-ant-oat-") == true)
        #expect(isOAuthToken("sk-ant-api-abc123") == false)
        #expect(isOAuthToken("sk-proj-abc123") == false)
        #expect(isOAuthToken("") == false)
    }

    @Test("AIProvider has correct env key names")
    func testEnvKeyNames() {
        #expect(AIProvider.anthropic.envKeyName == "ANTHROPIC_API_KEY")
        #expect(AIProvider.openai.envKeyName == "OPENAI_API_KEY")
    }

    @Test("AIProvider has correct default models")
    func testDefaultModels() {
        #expect(AIProvider.anthropic.defaultModel.contains("claude"))
        #expect(AIProvider.openai.defaultModel.contains("gpt"))
    }
}
