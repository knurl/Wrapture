import Foundation

enum Settings {
    static let defaultWrapLength = 80
    static let minimumWrapLength = 64
    static let maximumWrapLength = 128
    static let stepSize = 8
    static let wrapLengthKey = "wrapLength"
    static let appGroupIdentifier = "group.com.robanderson.wrapture"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func clampedWrapLength(_ value: Int) -> Int {
        min(max(value, minimumWrapLength), maximumWrapLength)
    }
}
