/// What an edge controls.
public enum EdgeControl: Sendable, Equatable {
    case brightness
    case volume
}

public enum StepDirection: Sendable, Equatable {
    case up
    case down
}

/// What the gesture engine asks the system to do.
public enum EdgeAction: Sendable, Equatable {
    /// A finger landed on a side edge and may become a slide. Remember where the pointer is.
    case slideArmed
    /// The finger is now sliding an edge. Freeze the pointer if wanted.
    case slideBegan(EdgeControl)
    /// Move the control one step. `fine` asks for a quarter step.
    case step(EdgeControl, StepDirection, fine: Bool)
    /// The sliding finger lifted.
    case slideEnded
    case toggleMute
    case playPause
    case nextTrack
    case previousTrack
}
