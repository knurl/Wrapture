import Foundation

enum WraptureSettings {
    static let defaultWrapLength = 96
    static let minimumWrapLength = 40
    static let maximumWrapLength = 160
    static let wrapLengthKey = "wrapLength"
    static let appGroupIdentifier = "group.com.robanderson.wrapture"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static var wrapLength: Int {
        let storedValue = defaults.integer(forKey: wrapLengthKey)
        guard storedValue > 0 else { return defaultWrapLength }
        return clampedWrapLength(storedValue)
    }

    static func clampedWrapLength(_ value: Int) -> Int {
        min(max(value, minimumWrapLength), maximumWrapLength)
    }
}
