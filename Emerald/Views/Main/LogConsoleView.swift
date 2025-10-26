//
//  LogConsoleView.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import SwiftUI

struct LogConsoleView: View {
    @ObservedObject var logManager = LogManager.shared
    @State private var autoScroll = true
    @State private var filterLevel: LogManager.LogEntry.LogLevel?
    
    var filteredLogs: [LogManager.LogEntry] {
        if let filter = filterLevel {
            return logManager.logs.filter { $0.level == filter }
        }
        return logManager.logs
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Debug Console")
                    .font(.headline)
                
                Spacer()
                
                // Filters
                Menu("Filter") {
                    Button("All") { filterLevel = nil }
                    Divider()
                    Button("🔍 Debug") { filterLevel = .debug }
                    Button("ℹ️ Info") { filterLevel = .info }
                    Button("⚠️ Warning") { filterLevel = .warning }
                    Button("❌ Error") { filterLevel = .error }
                    Button("✅ Success") { filterLevel = .success }
                }
                .frame(width: 80)
                
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .frame(width: 120)
                
                Button("Clear") {
                    logManager.clear()
                }
                .buttonStyle(.bordered)
                
                Button {
                    logManager.isVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(.regularMaterial)
            
            Divider()
            
            // Log list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredLogs) { entry in
                            LogEntryRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: logManager.logs.count) { _ in
                    if autoScroll, let lastLog = filteredLogs.last {
                        withAnimation {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(height: 300)
    }
}

struct LogEntryRow: View {
    let entry: LogManager.LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.level.rawValue)
                .font(.system(size: 12))
            
            Text(entry.formattedTime)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            
            Text("[\(entry.category)]")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(categoryColor(entry.category))
                .frame(width: 100, alignment: .leading)
            
            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
            
            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(levelBackground(entry.level))
        .cornerRadius(4)
    }
    
    func categoryColor(_ category: String) -> Color {
        switch category {
        case "ROM": return .blue
        case "CPU": return .purple
        case "Memory": return .orange
        case "PPU": return .green
        case "Input": return .pink
        case "Audio": return .cyan
        case "Error": return .red
        default: return .primary
        }
    }
    
    func levelBackground(_ level: LogManager.LogEntry.LogLevel) -> Color {
        switch level {
        case .error:
            return Color.red.opacity(0.1)
        case .warning:
            return Color.yellow.opacity(0.1)
        case .success:
            return Color.green.opacity(0.05)
        default:
            return Color.clear
        }
    }
}

#Preview {
    LogConsoleView()
        .frame(width: 800, height: 300)
}
