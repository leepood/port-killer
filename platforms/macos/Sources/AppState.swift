import Foundation
import SwiftUI
import Defaults
import KeyboardShortcuts
import Sparkle

// MARK: - Defaults Keys

extension Defaults.Keys {
    static let favorites = Key<Set<Int>>("favorites", default: [])
    static let watchedPorts = Key<[WatchedPort]>("watchedPorts", default: [])
    static let useTreeView = Key<Bool>("useTreeView", default: false)
    static let hideSystemProcesses = Key<Bool>("hideSystemProcesses", default: false)
    static let refreshInterval = Key<Int>("refreshInterval", default: 5)

    // Kubernetes-related keys
    static let customNamespaces = Key<[String]>("customNamespaces", default: [])

    // Sponsor-related keys
    static let sponsorCache = Key<SponsorCache?>("sponsorCache", default: nil)
    static let lastSponsorWindowShown = Key<Date?>("lastSponsorWindowShown", default: nil)
    static let sponsorDisplayInterval = Key<SponsorDisplayInterval>("sponsorDisplayInterval", default: .bimonthly)
}

// MARK: - Keyboard Shortcuts

extension KeyboardShortcuts.Name {
    static let toggleMainWindow = Self("toggleMainWindow")
}

// MARK: - App State

/// AppState manages the core application state including ports, favorites,
/// watched ports, filters, keyboard shortcuts, and auto-refresh functionality.
@Observable
@MainActor
final class AppState {
    // MARK: - Decomposed State Objects

    /// Manages favorite ports (extracted state)
    let favoritesState: FavoritesState

    /// Manages watched ports (extracted state)
    let watchedPortsState: WatchedPortsState

    // MARK: - Port State

    /// All currently scanned ports
    var ports: [PortInfo] = []

    /// Whether a port scan is currently in progress
    var isScanning = false

    // MARK: - Filter State

    /// Current filter settings for the port list
    var filter = PortFilter()

    /// Currently selected sidebar item (affects which ports are shown)
    var selectedSidebarItem: SidebarItem = .allPorts

    /// ID of the currently selected port in the detail view
    var selectedPortID: UUID? = nil

    /// The currently selected port, if any
    var selectedPort: PortInfo? {
        guard let id = selectedPortID else { return nil }
        return ports.first { $0.id == id }
    }

    /// ID of the currently selected port-forward connection
    var selectedPortForwardConnectionId: UUID? = nil

    /// The currently selected port-forward connection, if any
    var selectedPortForwardConnection: PortForwardConnectionState? {
        guard let id = selectedPortForwardConnectionId else { return nil }
        return portForwardManager.connections.first { $0.id == id }
    }

    /// Returns filtered ports based on sidebar selection and active filters.
    var filteredPorts: [PortInfo] {
        if case .settings = selectedSidebarItem { return [] }

        var result: [PortInfo]

        switch selectedSidebarItem {
        case .allPorts, .settings, .sponsors, .kubernetesPortForward, .cloudflareTunnels:
            result = ports
        case .favorites:
            var activePorts = Set<Int>()
            result = ports.compactMap { port -> PortInfo? in
                guard favorites.contains(port.port) else { return nil }
                activePorts.insert(port.port)
                return port
            }
            for favPort in favorites where !activePorts.contains(favPort) {
                result.append(PortInfo.inactive(port: favPort))
            }
        case .watched:
            let watchedPortNumbers = Set(watchedPorts.map { $0.port })
            var activePorts = Set<Int>()
            result = ports.compactMap { port -> PortInfo? in
                guard watchedPortNumbers.contains(port.port) else { return nil }
                activePorts.insert(port.port)
                return port
            }
            for watchedPort in watchedPortNumbers where !activePorts.contains(watchedPort) {
                result.append(PortInfo.inactive(port: watchedPort))
            }
        case .processType(let type):
            result = ports.filter { $0.processType == type }
        }

        if filter.isActive {
            result = result.filter { filter.matches($0, favorites: favorites, watched: watchedPorts) }
        }

        if Defaults[.hideSystemProcesses] {
            result = result.filter { $0.processType != .system }
        }

        return result
    }

    // MARK: - Backward Compatibility Accessors

    /// Port numbers marked as favorites by the user (delegates to FavoritesState)
    var favorites: Set<Int> {
        get { favoritesState.favorites }
        set { favoritesState.favorites = newValue }
    }

    /// Ports being watched for state changes (delegates to WatchedPortsState)
    var watchedPorts: [WatchedPort] {
        get { watchedPortsState.watchedPorts }
        set { watchedPortsState.watchedPorts = newValue }
    }

    /// Tracks previous port states for watch notifications (delegates to WatchedPortsState)
    var previousPortStates: [Int: Bool] {
        get { watchedPortsState.previousPortStates }
        set { watchedPortsState.previousPortStates = newValue }
    }

    // MARK: - Managers

    /// Manages Sparkle auto-update functionality
    let updateManager = UpdateManager()

    /// Manages Kubernetes port-forward connections
    let portForwardManager = PortForwardManager()

    /// Manages Cloudflare tunnel connections
    let tunnelManager = TunnelManager()

    // MARK: - Internal Properties (for extensions)

    /// Port scanning actor
    let scanner: PortScannerProtocol

    /// Background task for auto-refresh
    @ObservationIgnored var refreshTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        scanner: PortScannerProtocol = PortScanner(),
        favoritesState: FavoritesState? = nil,
        watchedPortsState: WatchedPortsState? = nil
    ) {
        self.scanner = scanner
        self.favoritesState = favoritesState ?? FavoritesState()
        self.watchedPortsState = watchedPortsState ?? WatchedPortsState()

        setupKeyboardShortcuts()
        startAutoRefresh()
    }

    deinit {
        refreshTask?.cancel()
    }
}
