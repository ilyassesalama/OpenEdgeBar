import AppKit
import CMultitouch
import EdgeBarCore
import IOKit
import OSLog
import os

/// A connected trackpad.
public struct Trackpad: Sendable, Hashable {
    /// Identifies the device object for as long as it is running.
    public let id: ObjectIdentifier
    /// The IORegistry "Multitouch ID", used to drive the haptic engine.
    public let multitouchID: UInt64
    public let familyID: Int32
    /// The surface's width divided by its height.
    public let aspectRatio: Double
}

/// A frame from one trackpad.
public struct TrackpadFrame: Sendable {
    public let trackpad: ObjectIdentifier
    public let frame: TouchFrame
}

/// Streams raw touches from every trackpad, and keeps doing so across sleep, fast user switching
/// and trackpads being connected or disconnected.
@MainActor
public final class TrackpadMonitor {
    /// Called on the main thread for every frame, in order.
    public var onFrame: ((TrackpadFrame) -> Void)?
    /// Called after every (re)start and stop. Engines for earlier devices should be dropped.
    public var onTrackpadsChanged: (([Trackpad]) -> Void)?

    public private(set) var trackpads: [Trackpad] = []

    /// Owns the device objects. The array holds the only reference to each device, so it must
    /// outlive their use and its members must never be released on their own.
    private var deviceList: CFArray?
    private var devices: [MTDevice] = []
    /// Bumped on every restart, so frames already queued from the previous devices are dropped.
    private var generation = 0
    private var isAsleep = false
    private var isSessionActive = true
    private var restartTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var hotplugPort: IONotificationPortRef?
    private var hotplugIterators: [io_iterator_t] = []

    public init() {}

    /// Starts listening. Safe to call again; it re-creates every device.
    public func start() {
        stopDevices()
        guard let framework = MultitouchFramework.shared else {
            Logger.touch.error("MultitouchSupport could not be loaded")
            publish([])
            return
        }

        generation += 1
        let current = generation
        FrameRelay.shared.setSink { [weak self] frame in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, self.generation == current else { return }
                    self.onFrame?(frame)
                }
            }
        }

        guard let list = framework.createList()?.takeRetainedValue() as CFArray? else {
            Logger.touch.error("No multitouch device list")
            publish([])
            return
        }
        var found: [Trackpad] = []
        var running: [MTDevice] = []
        for index in 0..<CFArrayGetCount(list) {
            guard let raw = CFArrayGetValueAtIndex(list, index) else { continue }
            let device = Unmanaged<CFTypeRef>.fromOpaque(raw).takeUnretainedValue()
            var family: Int32 = 0
            _ = framework.getFamilyID(device, &family)
            guard !Self.excludedFamilies.contains(family) else { continue }
            var multitouchID: UInt64 = 0
            _ = framework.getDeviceID(device, &multitouchID)
            var width: Int32 = 0
            var height: Int32 = 0
            _ = framework.getSurfaceDimensions(device, &width, &height)

            guard framework.register(device, contactFrameCallback) else {
                Logger.touch.error("Could not register for frames on device family \(family)")
                continue
            }
            let status = framework.start(device, MTRunModeQuiet)
            guard status == 0 else {
                Logger.touch.error("Could not start device family \(family): \(status)")
                _ = framework.unregister(device, contactFrameCallback)
                continue
            }
            running.append(device)
            found.append(Trackpad(
                id: ObjectIdentifier(device),
                multitouchID: multitouchID,
                familyID: family,
                aspectRatio: Self.aspectRatio(width: width, height: height)
            ))
        }
        deviceList = list
        devices = running
        Logger.touch.info("Listening to \(found.count) trackpad(s)")
        publish(found)
        watchSystemEvents()
    }

    public func stop() {
        restartTask?.cancel()
        restartTask = nil
        stopDevices()
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
        stopHotplug()
        publish([])
    }

    /// Restarts after a short pause, coalescing bursts of events (wake, hotplug). Never while the
    /// Mac sleeps or another user's session is in front.
    func scheduleRestart(after delay: Duration) {
        restartTask?.cancel()
        guard !isAsleep, isSessionActive else { return }
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled, !self.isAsleep, self.isSessionActive else { return }
            self.start()
        }
    }

    // MARK: - Devices

    /// Magic Mouse (112, 113) and the Touch Bar (176) are multitouch devices too, but not trackpads.
    nonisolated static let excludedFamilies: Set<Int32> = [112, 113, 176]

    nonisolated static func aspectRatio(width: Int32, height: Int32) -> Double {
        guard width > 0, height > 0 else { return EdgeGestureEngine.Tuning.defaultAspectRatio }
        return Double(width) / Double(height)
    }

    /// Never stop and then restart the same device object: stopping one that restarted moments
    /// ago crashes inside the framework. Restarts always create fresh objects instead.
    private func stopDevices() {
        guard let framework = MultitouchFramework.shared else { return }
        for device in devices {
            _ = framework.unregister(device, contactFrameCallback)
            _ = framework.stop(device)
        }
        devices.removeAll()
        deviceList = nil
    }

    /// Always notifies: a restart can hand out new device objects at the old addresses, so an
    /// unchanged-looking list may still mean every engine must start over.
    private func publish(_ found: [Trackpad]) {
        trackpads = found
        onTrackpadsChanged?(found)
    }

    private func pause() {
        restartTask?.cancel()
        stopDevices()
        publish([])
    }

    // MARK: - System events

    private func watchSystemEvents() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        let handlers: [(Notification.Name, @MainActor @Sendable (TrackpadMonitor) -> Void)] = [
            (NSWorkspace.willSleepNotification, { $0.isAsleep = true; $0.pause() }),
            (NSWorkspace.didWakeNotification, { $0.isAsleep = false; $0.scheduleRestart(after: .seconds(2)) }),
            (NSWorkspace.sessionDidResignActiveNotification, { $0.isSessionActive = false; $0.pause() }),
            (NSWorkspace.sessionDidBecomeActiveNotification, { $0.isSessionActive = true; $0.scheduleRestart(after: .seconds(1)) }),
        ]
        for (name, handle) in handlers {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    handle(self)
                }
            })
        }
        watchHotplug()
    }

    private func watchHotplug() {
        guard hotplugPort == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        IONotificationPortSetDispatchQueue(port, .main)
        hotplugPort = port
        let context = Unmanaged.passUnretained(self).toOpaque()
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            let result = IOServiceAddMatchingNotification(
                port, type, IOServiceMatching("AppleMultitouchDevice"), hotplugCallback, context, &iterator
            )
            guard result == KERN_SUCCESS else { continue }
            // Draining arms the notification; devices present now are already handled.
            drain(iterator)
            hotplugIterators.append(iterator)
        }
    }

    private func stopHotplug() {
        for iterator in hotplugIterators {
            IOObjectRelease(iterator)
        }
        hotplugIterators.removeAll()
        if let hotplugPort {
            IONotificationPortDestroy(hotplugPort)
        }
        hotplugPort = nil
    }
}

private func drain(_ iterator: io_iterator_t) {
    while case let service = IOIteratorNext(iterator), service != 0 {
        IOObjectRelease(service)
    }
}

/// Runs on the main queue (set with IONotificationPortSetDispatchQueue).
private let hotplugCallback: IOServiceMatchingCallback = { context, iterator in
    drain(iterator)
    guard let context else { return }
    let monitor = Unmanaged<TrackpadMonitor>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated {
        // New devices can take a moment to appear in the device list.
        monitor.scheduleRestart(after: .milliseconds(1500))
    }
}

// MARK: - Frame delivery

/// Hands frames from the framework's per-device threads to whoever is listening.
final class FrameRelay: Sendable {
    static let shared = FrameRelay()

    /// The closure lives inside a struct on purpose. Stored directly as the lock's generic state,
    /// every read wraps it in one more conversion thunk, and at 120 frames a second the chain
    /// grows until the callback thread's stack overflows.
    private struct Sink: Sendable {
        let send: @Sendable (TrackpadFrame) -> Void
    }

    private let sink = OSAllocatedUnfairLock<Sink?>(initialState: nil)

    func setSink(_ newSink: @escaping @Sendable (TrackpadFrame) -> Void) {
        sink.withLock { $0 = Sink(send: newSink) }
    }

    func send(_ frame: TrackpadFrame) {
        sink.withLock { $0 }?.send(frame)
    }
}

/// Runs on a framework-owned background thread. Copies the touches out before returning, since
/// the buffer is only valid during the call.
private let contactFrameCallback: MTContactFrameCallback = { device, touches, count, timestamp, _ in
    guard let device else { return }
    let contacts = UnsafeBufferPointer(start: touches, count: touches == nil ? 0 : max(Int(count), 0))
    FrameRelay.shared.send(TrackpadFrame(
        trackpad: ObjectIdentifier(device),
        frame: TouchFrame(timestamp: timestamp, touches: MultitouchFramework.fingers(in: contacts))
    ))
}
