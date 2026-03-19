import Foundation
import Testing
@testable import Shellmate

@Suite("AIError")
struct AIErrorTests {

    @Test("all error cases have descriptions")
    func testErrorDescriptions() {
        let cases: [AIError] = [
            .invalidResponse,
            .apiError(statusCode: 400, message: "Bad request"),
            .noApiKey,
            .cancelled,
            .networkUnavailable,
            .rateLimited(retryAfter: 30),
            .rateLimited(retryAfter: nil),
            .invalidApiKey,
        ]

        for error in cases {
            #expect(error.errorDescription != nil, "Missing description for \(error)")
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("rate limited includes retry time")
    func testRateLimitedDescription() {
        let withRetry = AIError.rateLimited(retryAfter: 30)
        #expect(withRetry.errorDescription!.contains("30"))

        let withoutRetry = AIError.rateLimited(retryAfter: nil)
        #expect(withoutRetry.errorDescription!.contains("shortly"))
    }

    @Test("api error includes status code")
    func testApiErrorDescription() {
        let error = AIError.apiError(statusCode: 429, message: "Rate limit exceeded")
        #expect(error.errorDescription!.contains("429"))
        #expect(error.errorDescription!.contains("Rate limit exceeded"))
    }
}

@Suite("RetryableError")
struct RetryableErrorTests {

    @Test("wraps underlying error")
    func testRetryableError() {
        let underlying = AIError.apiError(statusCode: 429, message: "Too many requests")
        let retryable = RetryableError(underlying: underlying, retryAfter: 5.0)

        #expect(retryable.retryAfter == 5.0)
        #expect(retryable.underlying is AIError)
    }

    @Test("retryAfter can be nil")
    func testRetryableNoRetryAfter() {
        let underlying = AIError.apiError(statusCode: 500, message: "Server error")
        let retryable = RetryableError(underlying: underlying, retryAfter: nil)

        #expect(retryable.retryAfter == nil)
    }
}
