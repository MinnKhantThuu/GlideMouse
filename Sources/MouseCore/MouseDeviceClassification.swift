import Foundation

public enum MouseDeviceClassification {
    /// Composite keyboards can advertise a mouse collection for media/pointing controls.
    public static func isMouse(name: String, keyboardCollection: Bool, touchpadCollection: Bool) -> Bool {
        let normalized = name.lowercased()
        let words = normalized.split { !$0.isLetter && !$0.isNumber }
        if normalized.contains("keyboard") || normalized.contains("trackpad") || normalized.contains("touchpad") || words.contains("kb") { return false }
        if touchpadCollection { return false }
        if keyboardCollection && !normalized.contains("mouse") { return false }
        return true
    }
}
