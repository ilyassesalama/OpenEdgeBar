import CMultitouch
import EdgeBarCore
import Foundation

/// Function pointers into MultitouchSupport, looked up once.
struct MultitouchFramework: @unchecked Sendable {
    let createList: MTDeviceCreateListFunction
    let register: MTRegisterContactFrameCallbackFunction
    let unregister: MTUnregisterContactFrameCallbackFunction
    let start: MTDeviceStartFunction
    let stop: MTDeviceStopFunction
    let getFamilyID: MTDeviceGetFamilyIDFunction
    let getDeviceID: MTDeviceGetDeviceIDFunction
    let getSurfaceDimensions: MTDeviceGetSensorSurfaceDimensionsFunction
    /// Haptics are optional: nil when any actuator function is missing.
    let actuator: Actuator?

    struct Actuator {
        let create: MTActuatorCreateFromDeviceIDFunction
        let open: MTActuatorOpenFunction
        let close: MTActuatorCloseFunction
        let actuate: MTActuatorActuateFunction
    }

    static let shared = MultitouchFramework()

    private init?() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else {
            return nil
        }
        func symbol<T>(_ name: String) -> T? {
            dlsym(handle, name).map { unsafeBitCast($0, to: T.self) }
        }
        guard
            let createList: MTDeviceCreateListFunction = symbol("MTDeviceCreateList"),
            let register: MTRegisterContactFrameCallbackFunction = symbol("MTRegisterContactFrameCallback"),
            let unregister: MTUnregisterContactFrameCallbackFunction = symbol("MTUnregisterContactFrameCallback"),
            let start: MTDeviceStartFunction = symbol("MTDeviceStart"),
            let stop: MTDeviceStopFunction = symbol("MTDeviceStop"),
            let getFamilyID: MTDeviceGetFamilyIDFunction = symbol("MTDeviceGetFamilyID"),
            let getDeviceID: MTDeviceGetDeviceIDFunction = symbol("MTDeviceGetDeviceID"),
            let getSurfaceDimensions: MTDeviceGetSensorSurfaceDimensionsFunction = symbol("MTDeviceGetSensorSurfaceDimensions")
        else {
            return nil
        }
        self.createList = createList
        self.register = register
        self.unregister = unregister
        self.start = start
        self.stop = stop
        self.getFamilyID = getFamilyID
        self.getDeviceID = getDeviceID
        self.getSurfaceDimensions = getSurfaceDimensions
        if let create: MTActuatorCreateFromDeviceIDFunction = symbol("MTActuatorCreateFromDeviceID"),
           let open: MTActuatorOpenFunction = symbol("MTActuatorOpen"),
           let close: MTActuatorCloseFunction = symbol("MTActuatorClose"),
           let actuate: MTActuatorActuateFunction = symbol("MTActuatorActuate") {
            actuator = Actuator(create: create, open: open, close: close, actuate: actuate)
        } else {
            actuator = nil
        }
    }

    /// Contacts this long or longer (in millimeters) are palms or flat thumbs. Fingertips measure
    /// about 6 to 9.
    static let palmMajorAxis: Float = 10

    /// The fingers touching the surface, from one frame's raw contacts.
    static func fingers(in contacts: UnsafeBufferPointer<MTTouch>) -> [Touch] {
        contacts.compactMap { contact in
            // The frame also carries hovering and lifting contacts.
            guard contact.state == .makeTouch || contact.state == .touching,
                  contact.majorAxis < palmMajorAxis
            else { return nil }
            return Touch(
                id: Int(contact.pathIndex),
                x: Double(contact.normalized.position.x),
                y: Double(contact.normalized.position.y)
            )
        }
    }
}
