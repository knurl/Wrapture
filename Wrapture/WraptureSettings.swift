//
//  WraptureSettings.swift
//  Wrapture
//
//  Created by Rob Anderson on 11/09/2026.
//

import Foundation

enum WraptureSettings {
    static let defaultWrapLength = 96
    static let minimumWrapLength = 40
    static let maximumWrapLength = 160
    static let wrapLengthKey = "wrapLength"
    static let appGroupIdentifier = "group.com.robanderson.Wrapture"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func clampedWrapLength(_ value: Int) -> Int {
        min(max(value, minimumWrapLength), maximumWrapLength)
    }
}
