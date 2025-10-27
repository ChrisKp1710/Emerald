//
//  GBARom.swift
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

import Foundation
import SwiftUI
import CryptoKit
import UniformTypeIdentifiers

/// Represents a GBA ROM with metadata
struct GBARom: Identifiable, Codable, Hashable {
    let id = UUID()
    let url: URL
    let saveURL: URL
    
    // ROM Header Information
    let title: String
    let gameCode: String
    let makerCode: String
    let publisher: String
    let region: String
    let version: UInt8
    let checksum: String
    let romSize: Int
    
    // Library Metadata
    let dateAdded: Date
    var lastPlayed: Date?
    var totalPlaytime: TimeInterval = 0
    var rating: Int = 0
    var notes: String = ""
    var category: ROMCategory = .unknown
    var isFavorite: Bool = false
    
    // Computed Properties
    var displayTitle: String {
        return title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
               url.deletingPathExtension().lastPathComponent : title
    }
    
    var formattedPlaytime: String {
        let hours = Int(totalPlaytime) / 3600
        let minutes = Int(totalPlaytime) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(romSize))
    }
    
    // MARK: - Initialization
    
    init(url: URL, header: ROMHeader) {
        self.url = url
        self.saveURL = url.deletingPathExtension().appendingPathExtension("sav")
        
        self.title = header.title
        self.gameCode = header.gameCode
        self.makerCode = header.makerCode
        self.publisher = PublisherDatabase.shared.getName(for: header.makerCode)
        self.region = RegionDetector.detect(from: header.gameCode)
        self.version = header.version
        self.checksum = header.checksum
        self.romSize = header.romSize
        
        self.dateAdded = Date()
        self.category = CategoryDetector.detect(from: header.gameCode, title: header.title)
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case url, saveURL, title, gameCode, makerCode, publisher, region, version
        case checksum, romSize, dateAdded, lastPlayed, totalPlaytime, rating
        case notes, category, isFavorite
    }
}

/// ROM Category for organization
enum ROMCategory: String, CaseIterable, Codable {
    case action = "Action"
    case adventure = "Adventure"
    case fighting = "Fighting"
    case platform = "Platform"
    case puzzle = "Puzzle"
    case racing = "Racing"
    case rpg = "RPG"
    case shooter = "Shooter"
    case simulation = "Simulation"
    case sports = "Sports"
    case strategy = "Strategy"
    case educational = "Educational"
    case homebrew = "Homebrew"
    case demo = "Demo"
    case unknown = "Unknown"
    
    var color: Color {
        switch self {
        case .action: return .red
        case .adventure: return .green
        case .fighting: return .orange
        case .platform: return .blue
        case .puzzle: return .purple
        case .racing: return .yellow
        case .rpg: return .pink
        case .shooter: return .red
        case .simulation: return .gray
        case .sports: return .green
        case .strategy: return .blue
        case .educational: return .cyan
        case .homebrew: return .mint
        case .demo: return .orange
        case .unknown: return .secondary
        }
    }
    
    var systemImage: String {
        switch self {
        case .action: return "figure.run"
        case .adventure: return "map"
        case .fighting: return "hand.raised"
        case .platform: return "square.stack.3d.up"
        case .puzzle: return "puzzlepiece"
        case .racing: return "car"
        case .rpg: return "shield.lefthalf.filled" // RPG icon (sword alternativa: shield/wand.and.stars)
        case .shooter: return "scope"
        case .simulation: return "gear"
        case .sports: return "sportscourt"
        case .strategy: return "brain.head.profile"
        case .educational: return "book"
        case .homebrew: return "hammer"
        case .demo: return "play.circle"
        case .unknown: return "gamecontroller"
        }
    }
}

/// ROM Library view styles
enum ViewStyle: String, CaseIterable {
    case grid = "Grid"
    case list = "List"
    
    var systemImage: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

/// ROM Library sort orders
enum SortOrder: String, CaseIterable {
    case title = "Title"
    case dateAdded = "Date Added"
    case lastPlayed = "Last Played"
    case playtime = "Play Time"
    case publisher = "Publisher"
}

/// ROM Library errors
enum ROMLibraryError: LocalizedError {
    case romAlreadyExists
    case invalidROMFormat
    case failedToParseHeader
    case failedToCreateSaveDirectory
    
    var errorDescription: String? {
        switch self {
        case .romAlreadyExists:
            return "ROM already exists in library"
        case .invalidROMFormat:
            return "Invalid ROM format"
        case .failedToParseHeader:
            return "Failed to parse ROM header"
        case .failedToCreateSaveDirectory:
            return "Failed to create save directory"
        }
    }
}

// MARK: - ROM Header

struct ROMHeader {
    let title: String
    let gameCode: String
    let makerCode: String
    let version: UInt8
    let checksum: String
    let romSize: Int
    
    init(data: Data) throws {
        guard data.count >= 0xC0 else {
            throw ROMLibraryError.failedToParseHeader
        }
        
        // Extract title (0xA0-0xAB)
        let titleData = data.subdata(in: 0xA0..<0xAC)
        self.title = String(data: titleData, encoding: .ascii)?
                        .trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines)) ?? "Unknown"
        
        // Extract game code (0xAC-0xAF)
        let gameCodeData = data.subdata(in: 0xAC..<0xB0)
        self.gameCode = String(data: gameCodeData, encoding: .ascii) ?? "UNKN"
        
        // Extract maker code (0xB0-0xB1)
        let makerCodeData = data.subdata(in: 0xB0..<0xB2)
        self.makerCode = String(data: makerCodeData, encoding: .ascii) ?? "??"
        
        // Extract version (0xBC)
        self.version = data[0xBC]
        
        // Calculate checksum
        let hash = SHA256.hash(data: data)
        self.checksum = hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).uppercased()
        
        self.romSize = data.count
    }
}

// MARK: - Supporting Classes

class PublisherDatabase {
    static let shared = PublisherDatabase()
    
    private let publishers: [String: String] = [
        "01": "Nintendo",
        "08": "Capcom",
        "13": "Electronic Arts",
        "18": "Hudson Soft",
        "20": "KSS",
        "22": "Pow",
        "24": "PCM Complete",
        "25": "San-X",
        "28": "Kemco",
        "29": "Seta",
        "30": "Viacom",
        "31": "Nintendo",
        "32": "Bandai",
        "33": "Ocean/Acclaim",
        "34": "Konami",
        "35": "Hector",
        "37": "Taito",
        "38": "Hudson",
        "39": "Banpresto",
        "41": "Ubi Soft",
        "42": "Atlus",
        "44": "Malibu",
        "46": "Angel",
        "47": "Bullet-Proof",
        "49": "Irem",
        "50": "Absolute",
        "51": "Acclaim",
        "52": "Activision",
        "53": "American Sammy",
        "54": "Konami",
        "55": "Hi Tech Entertainment",
        "56": "LJN",
        "57": "Matchbox",
        "58": "Mattel",
        "59": "Milton Bradley",
        "60": "Titus",
        "61": "Virgin",
        "64": "LucasArts",
        "67": "Ocean",
        "69": "Electronic Arts",
        "70": "Infogrames",
        "71": "Interplay",
        "72": "Broderbund",
        "73": "Sculptured",
        "75": "SCI",
        "78": "THQ",
        "79": "Accolade",
        "80": "Misawa",
        "83": "Lozc",
        "86": "Tokuma Shoten Intermedia",
        "87": "Tsukuda Original",
        "91": "Chunsoft",
        "92": "Video System",
        "93": "Ocean/Acclaim",
        "95": "Varie",
        "96": "Yonezawa/S'pal",
        "97": "Kaneko",
        "99": "Pack in Video"
    ]
    
    func getName(for code: String) -> String {
        return publishers[code] ?? "Unknown Publisher"
    }
}

class RegionDetector {
    static func detect(from gameCode: String) -> String {
        guard gameCode.count >= 4 else { return "Unknown" }
        
        let regionCode = String(gameCode.suffix(1))
        
        switch regionCode.uppercased() {
        case "E": return "USA"
        case "P": return "Europe"
        case "J": return "Japan"
        case "F": return "France"
        case "D": return "Germany"
        case "I": return "Italy"
        case "S": return "Spain"
        default: return "Unknown"
        }
    }
}

class CategoryDetector {
    static func detect(from gameCode: String, title: String) -> ROMCategory {
        let titleLower = title.lowercased()
        
        // Check title keywords
        if titleLower.contains("pokemon") || titleLower.contains("final fantasy") || 
           titleLower.contains("fire emblem") || titleLower.contains("golden sun") {
            return .rpg
        }
        
        if titleLower.contains("mario") || titleLower.contains("sonic") ||
           titleLower.contains("crash") || titleLower.contains("rayman") {
            return .platform
        }
        
        if titleLower.contains("racing") || titleLower.contains("kart") ||
           titleLower.contains("formula") || titleLower.contains("rally") {
            return .racing
        }
        
        if titleLower.contains("puzzle") || titleLower.contains("tetris") ||
           titleLower.contains("puyo") {
            return .puzzle
        }
        
        if titleLower.contains("metroid") || titleLower.contains("castlevania") ||
           titleLower.contains("contra") {
            return .action
        }
        
        if titleLower.contains("zelda") {
            return .adventure
        }
        
        if titleLower.contains("street fighter") || titleLower.contains("tekken") ||
           titleLower.contains("mortal kombat") {
            return .fighting
        }
        
        if titleLower.contains("demo") {
            return .demo
        }
        
        return .unknown
    }
}