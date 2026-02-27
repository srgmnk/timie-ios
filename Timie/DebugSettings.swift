import Foundation

enum DebugSettings {
    static var enableCityDeleteDebug = true

    // Add feature-specific debug flags here as needed.
}

// How to capture delete-current traces:
// 1) Set `DebugSettings.enableCityDeleteDebug = true`.
// 2) Delete current city via swipe.
// 3) Share `[DELETE]` lines for that run.
