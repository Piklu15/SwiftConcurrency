//
//  EventLog.swift
//  SwiftConcurrency
//

import Foundation
import Observation

/// A small on-screen log so you can watch the order in which async events happen.
@Observable
final class EventLog {
    enum Kind {
        case info, success, warning, error
    }

    struct Entry: Identifiable {
        let id = UUID()
        let time = Date()
        let message: String
        let kind: Kind
    }

    private(set) var entries: [Entry] = []
    private let maxEntries = 60

    func add(_ message: String, _ kind: Kind = .info) {
        entries.insert(Entry(message: message, kind: kind), at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
