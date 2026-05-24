import Foundation

/// Debug-only logging helpers that include the calling file and line.
enum Log {
    /// Prints a debug message only in DEBUG builds.
    static func debug(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        line: Int = #line
    ) {
        #if DEBUG
            print("[\(filename(file)):\(line)] \(message())")
        #endif
    }

    /// Prints a warning message only in DEBUG builds.
    static func warning(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        line: Int = #line
    ) {
        #if DEBUG
            print("⚠️ [\(filename(file)):\(line)] \(message())")
        #endif
    }

    /// Prints an error message and triggers an assertion only in DEBUG builds.
    static func error(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        line: Int = #line
    ) {
        #if DEBUG
            let formatted = "🛑 [\(filename(file)):\(line)] \(message())"
            print(formatted)
            assertionFailure(formatted)
        #endif
    }

    private static func filename(_ fileID: String) -> String {
        fileID.components(separatedBy: "/").last ?? fileID
    }
}
