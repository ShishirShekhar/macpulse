import Foundation

/// One saved scan. Only the values the trend needs are kept, so the history file
/// stays small even after months of daily checks.
struct HistoryFix: Codable, Equatable, Identifiable {
    let id: String
    let title: String

    init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    init(_ fix: FixSuggestion) {
        self.id = fix.id
        self.title = fix.title
    }
}

struct HistoryEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let score: Int
    let fixes: [HistoryFix]
    let memFreePct: Double
    let diskFreePct: Double
    let load1: Double

    init(
        id: UUID = UUID(),
        date: Date,
        score: Int,
        fixes: [HistoryFix],
        memFreePct: Double,
        diskFreePct: Double,
        load1: Double
    ) {
        self.id = id
        self.date = date
        self.score = score
        self.fixes = fixes
        self.memFreePct = memFreePct
        self.diskFreePct = diskFreePct
        self.load1 = load1
    }

    init(id: UUID = UUID(), result: CheckResult) {
        self.init(
            id: id,
            date: result.date,
            score: result.score,
            fixes: result.fixes.map(HistoryFix.init),
            memFreePct: result.memFreePct,
            diskFreePct: result.diskFreePct,
            load1: result.load1
        )
    }
}

/// The differences worth telling the user about. Only stable fix IDs are compared,
/// so wording changes never show up as a new recommendation.
struct HistoryChange: Equatable {
    let previousDate: Date
    let scoreDelta: Int
    let addedFixes: [HistoryFix]
    let resolvedFixes: [HistoryFix]

    var hasChanges: Bool {
        scoreDelta != 0 || !addedFixes.isEmpty || !resolvedFixes.isEmpty
    }
}

/// Pure history rules: ordering, pruning and comparison. Persistence lives in
/// `HistoryStore` so these functions can be tested without touching disk.
enum ScanHistory {
    static let limit = 30

    /// Adds `entry` as the newest item and keeps only the most recent `limit`.
    static func append(_ entry: HistoryEntry, to entries: [HistoryEntry], limit: Int = limit) -> [HistoryEntry] {
        var updated = entries
        updated.append(entry)
        updated.sort { $0.date > $1.date }
        if updated.count > max(1, limit) {
            updated = Array(updated.prefix(max(1, limit)))
        }
        return updated
    }

    /// Newest entry strictly before `date` (history is newest-first).
    static func previousEntry(before date: Date, in entries: [HistoryEntry]) -> HistoryEntry? {
        entries.first { $0.date < date }
    }

    /// Most recent entry from an earlier calendar day, used for the "since
    /// yesterday" summary. Falls back to nil when there is no earlier day.
    static func previousDailyEntry(
        before date: Date,
        in entries: [HistoryEntry],
        calendar: Calendar = .current
    ) -> HistoryEntry? {
        let today = calendar.startOfDay(for: date)
        return entries.first { calendar.startOfDay(for: $0.date) < today }
    }

    static func change(from previous: HistoryEntry, to current: HistoryEntry) -> HistoryChange {
        let previousIDs = Set(previous.fixes.map(\.id))
        let currentIDs = Set(current.fixes.map(\.id))
        return HistoryChange(
            previousDate: previous.date,
            scoreDelta: current.score - previous.score,
            addedFixes: current.fixes.filter { !previousIDs.contains($0.id) },
            resolvedFixes: previous.fixes.filter { !currentIDs.contains($0.id) }
        )
    }

    /// Summary string for the trend card. Kept here so it can be unit tested.
    static func summary(for change: HistoryChange) -> String {
        if !change.hasChanges { return L10n.t("history.noChange") }

        var parts: [String] = []
        if change.scoreDelta > 0 {
            parts.append(L10n.t("history.scoreUp", change.scoreDelta))
        } else if change.scoreDelta < 0 {
            parts.append(L10n.t("history.scoreDown", abs(change.scoreDelta)))
        } else {
            parts.append(L10n.t("history.scoreSame"))
        }
        if !change.addedFixes.isEmpty {
            parts.append(L10n.t("history.newFixes", change.addedFixes.map(\.title).joined(separator: ", ")))
        }
        if !change.resolvedFixes.isEmpty {
            parts.append(L10n.t("history.resolvedFixes", change.resolvedFixes.map(\.title).joined(separator: ", ")))
        }
        return parts.joined(separator: " · ")
    }
}

/// Reads and writes the history file next to `last-check.json`.
enum HistoryStore {
    static var url: URL {
        SystemCheck.supportDirectory.appendingPathComponent("history.json")
    }

    static func load() -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([HistoryEntry].self, from: data)) ?? []
    }

    static func save(_ entries: [HistoryEntry]) {
        do {
            try FileManager.default.createDirectory(
                at: SystemCheck.supportDirectory,
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(entries).write(to: url, options: .atomic)
        } catch {
            NSLog("MacPulse history save failed: \(error)")
        }
    }

    /// Appends one scan and returns the pruned list.
    @discardableResult
    static func record(_ result: CheckResult) -> [HistoryEntry] {
        let updated = ScanHistory.append(HistoryEntry(result: result), to: load())
        save(updated)
        return updated
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
