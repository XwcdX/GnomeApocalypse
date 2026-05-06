import Foundation

enum Log {
    static func debug(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        line: Int = #line
    ) {
        #if DEBUG
            print("[\(filename(file)):\(line)] \(message())")
        #endif
    }

    static func warning(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        line: Int = #line
    ) {
        #if DEBUG
            print("⚠️ [\(filename(file)):\(line)] \(message())")
        #endif
    }

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
