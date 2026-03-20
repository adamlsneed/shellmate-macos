import Foundation
import Network
import os

/// Monitors network connectivity using NWPathMonitor.
/// Use `NetworkMonitor.shared` for app-wide connectivity checks.
@Observable
@MainActor
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private static let logger = Logger(subsystem: "com.shellmate.app", category: "network")

    /// Whether the device currently has network connectivity.
    private(set) var isConnected: Bool = true

    /// Whether the connection uses an expensive interface (cellular, hotspot).
    private(set) var isExpensive: Bool = false

    /// The current interface type (wifi, cellular, wiredEthernet, etc.).
    private(set) var interfaceType: NWInterface.InterfaceType?

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.shellmate.network-monitor")

    private init() {
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                self.isExpensive = path.isExpensive

                if path.usesInterfaceType(.wifi) {
                    self.interfaceType = .wifi
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.interfaceType = .wiredEthernet
                } else if path.usesInterfaceType(.cellular) {
                    self.interfaceType = .cellular
                } else {
                    self.interfaceType = nil
                }

                if wasConnected && !self.isConnected {
                    Self.logger.warning("Network connection lost")
                } else if !wasConnected && self.isConnected {
                    Self.logger.info("Network connection restored")
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    /// Check connectivity and throw if offline.
    /// Call before making network requests to provide a clear error message.
    /// Uses the monitor's cached state rather than creating a new NWPathMonitor each call.
    func requireConnectivity() throws {
        if !isConnected {
            throw AIError.networkUnavailable
        }
    }
}

/// Request logging helper using os.Logger.
enum NetworkLogger {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "network-request")

    /// Log an outbound request (method, URL, body size).
    static func logRequest(_ request: URLRequest) {
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        let bodySize = request.httpBody?.count ?? 0
        logger.info("\(method) \(url) (body: \(bodySize) bytes)")
    }

    /// Log a response (status code, body size, duration).
    static func logResponse(_ response: HTTPURLResponse, dataSize: Int, duration: TimeInterval) {
        let url = response.url?.absoluteString ?? "unknown"
        logger.info("\(response.statusCode) \(url) (\(dataSize) bytes, \(String(format: "%.2f", duration))s)")
    }

    /// Log a network error.
    static func logError(_ error: Error, url: String) {
        logger.error("Request failed: \(url) - \(error.localizedDescription)")
    }
}
