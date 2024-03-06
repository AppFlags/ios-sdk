
import Foundation

public enum LogLevel: Int {
    case debug
    case info
    case warn
    case error
}

class Logger {
    
    static var logLevel: LogLevel = LogLevel.warn
    
    private static func log(_ level: LogLevel, _ message: String) {
        if (level.rawValue >= Logger.logLevel.rawValue) {
            let levelString = String(describing: level)
            print("[AppFlags] [\(levelString)] \(message)")
        }
    }
    
    static func debug(_ message: String) {
        Logger.log(LogLevel.debug, message)
    }
    
    static func info(_ message: String) {
        Logger.log(LogLevel.info, message)
    }
    
    static func warn(_ message: String) {
        Logger.log(LogLevel.warn, message)
    }
    
    static func error(_ message: String) {
        Logger.log(LogLevel.error, message)
    }
    
    static func error(_ message: String, _ error: Error) {
        Logger.error("\(message): \(error)")
    }
}
