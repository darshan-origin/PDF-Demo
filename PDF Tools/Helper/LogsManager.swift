//
//  LogsManager.swift
//  PDF Tools
//
//  Created by mac on 17/02/26.
//

import os
import Foundation

enum LogLevel: String {
    case info = "ℹ️ [INFO]"
    case debug = "🛠️ [DEBUG]"
    case warning = "⚠️ [WARN]"
    case error = "❌ [ERROR]"
    case success = "✅ [SUCCESS]"
}

struct Logger {
    static func print(_ message: Any,
                      level: LogLevel = .debug,
                      file: String = #file,
                      function: String = #function,
                      line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "\(level.rawValue) \(fileName):\(line) -> \(function): \(message)"
        Swift.print(logMessage)
        #endif
    }
}
