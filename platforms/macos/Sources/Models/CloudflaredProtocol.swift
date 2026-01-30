import Defaults
import Foundation

/// Supported transport protocols for cloudflared quick tunnels.
enum CloudflaredProtocol: String, CaseIterable, Codable, Defaults.Serializable, Sendable {
    case http2 = "http2"
    case quic = "quic"

    var displayName: String {
        switch self {
        case .http2: return "HTTP/2"
        case .quic: return "QUIC"
        }
    }
}
