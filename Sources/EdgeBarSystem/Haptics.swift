import Foundation
import OSLog

/// Plays a click on the trackpad under the finger, through the trackpad's own actuator.
///
/// The public NSHapticFeedbackManager has a single fixed feel, so it cannot offer strengths.
///
/// Opening the actuator also takes over how the trackpad's own click feels, so it is only held
/// open while ticks are coming and closed shortly after the last one, handing clicks back to macOS.
@MainActor
public final class Haptics {
    /// Ticks closer together than this blur into a buzz, so extra ones are dropped.
    static let minimumInterval: TimeInterval = 0.05
    /// How long after the last tick the actuators are closed.
    static let idleDelay: Duration = .milliseconds(500)

    /// Open actuators, by Multitouch ID.
    private var actuators: [UInt64: CFTypeRef] = [:]
    private var lastTick: [UInt64: TimeInterval] = [:]
    private var idleClose: Task<Void, Never>?

    public init() {}

    /// The waveform for each strength: 3, 4 and 6 rise in strength on every actuator revision.
    static func actuationID(for strength: HapticStrength) -> Int32? {
        switch strength {
        case .off: nil
        case .light: 3
        case .medium: 4
        case .strong: 6
        }
    }

    /// Returns whether a click played.
    @discardableResult
    public func tick(_ strength: HapticStrength, on multitouchID: UInt64, at time: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard let id = Self.actuationID(for: strength), let functions = MultitouchFramework.shared?.actuator else { return false }
        if let last = lastTick[multitouchID], time - last < Self.minimumInterval { return false }
        lastTick[multitouchID] = time
        defer { scheduleIdleClose() }

        if let actuator = actuator(for: multitouchID, functions), functions.actuate(actuator, id, 0, 1, 0) == 0 {
            return true
        }
        // Handles can go stale, for example across sleep. Reopen once and try again.
        close(multitouchID, functions)
        guard let actuator = actuator(for: multitouchID, functions) else { return false }
        return functions.actuate(actuator, id, 0, 1, 0) == 0
    }

    /// Closes every actuator, for example when the trackpads change.
    public func reset() {
        closeAll()
        lastTick.removeAll()
    }

    private func scheduleIdleClose() {
        idleClose?.cancel()
        idleClose = Task { [weak self] in
            try? await Task.sleep(for: Self.idleDelay)
            guard !Task.isCancelled else { return }
            self?.closeAll()
        }
    }

    private func closeAll() {
        idleClose?.cancel()
        idleClose = nil
        guard let functions = MultitouchFramework.shared?.actuator else { return }
        for id in actuators.keys {
            close(id, functions)
        }
    }

    private func actuator(for multitouchID: UInt64, _ functions: MultitouchFramework.Actuator) -> CFTypeRef? {
        if let open = actuators[multitouchID] {
            return open
        }
        guard let actuator = functions.create(multitouchID)?.takeRetainedValue() else { return nil }
        let status = functions.open(actuator, 0)
        guard status == 0 else {
            Logger.system.error("Could not open the haptic actuator: \(status)")
            return nil
        }
        actuators[multitouchID] = actuator
        return actuator
    }

    private func close(_ multitouchID: UInt64, _ functions: MultitouchFramework.Actuator) {
        if let actuator = actuators.removeValue(forKey: multitouchID) {
            _ = functions.close(actuator)
        }
    }
}
