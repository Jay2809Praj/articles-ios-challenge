import Foundation
import XCGLogger

/// Creates the app-wide XCGLogger instance.
enum LoggerFactory {
    static func makeLogger() -> XCGLogger {
        let logger = XCGLogger(identifier: "com.jayprajapati.articles", includeDefaultDestinations: true)

        #if DEBUG
        let level: XCGLogger.Level = .verbose
        #else
        let level: XCGLogger.Level = .warning
        #endif

        logger.setup(
            level: level,
            showLogIdentifier: false,
            showFunctionName: false,
            showThreadName: false,
            showLevel: true,
            showFileNames: true,
            showLineNumbers: true,
            showDate: true
        )
        return logger
    }
}
