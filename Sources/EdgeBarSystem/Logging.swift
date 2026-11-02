import OSLog

extension Logger {
    static let system = Logger(subsystem: "app.openedgebar.OpenEdgeBar", category: "system")
    static let touch = Logger(subsystem: "app.openedgebar.OpenEdgeBar", category: "touch")
}
