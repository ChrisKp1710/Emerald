//
//  LogManager.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import Foundation
import OSLog
import Combine

/// Centralized logging manager for debugging
@MainActor
final class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: [LogEntry] = []
    @Published var isVisible = false
    
    private let maxLogs = 1000
    private let logger = Logger(subsystem: "com.emerald.gba", category: "LogManager")
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let category: String
        let level: LogLevel
        let message: String
        
        enum LogLevel: String {
            case debug = "🔍"
            case info = "ℹ️"
            case warning = "⚠️"
            case error = "❌"
            case success = "✅"
        }
        
        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
    }
    
    private init() {
        log("LogManager initialized", category: "System", level: .info)
    }
    
    func log(_ message: String, category: String = "General", level: LogEntry.LogLevel = .info) {
        let entry = LogEntry(
            timestamp: Date(),
            category: category,
            level: level,
            message: message
        )
        
        logs.append(entry)
        
        // Keep only last N logs
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
        
        // Also log to system
        switch level {
        case .debug:
            logger.debug("[\(category)] \(message)")
        case .info, .success:
            logger.info("[\(category)] \(message)")
        case .warning:
            logger.warning("[\(category)] \(message)")
        case .error:
            logger.error("[\(category)] \(message)")
        }
    }
    
    func clear() {
        logs.removeAll()
        log("Logs cleared", category: "System", level: .info)
    }
    
    func toggle() {
        isVisible.toggle()
    }
}
