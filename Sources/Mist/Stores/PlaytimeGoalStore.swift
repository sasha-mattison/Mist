import Foundation
import Observation

/// Local-only "play more of your library" features: a monthly playtime goal
/// tracked via a session log RunningGameMonitor feeds into (Steam's Web API
/// only exposes cumulative-forever and last-2-weeks playtime, never a
/// monthly breakdown, so this has to be logged locally rather than derived),
/// and a persisted backlog pick that only rerolls automatically after a
/// week — or on request — instead of re-randomizing every time the Backlog
/// sheet opens.
@MainActor
@Observable
final class PlaytimeGoalStore {
    static let shared = PlaytimeGoalStore()

    private(set) var sessions: [PlaySession] = []
    private(set) var pickedBacklogAppID: Int?
    private(set) var pickedBacklogDate: Date?

    private let cacheFileURL: URL

    private static let goalMinutesKey = "playtimeGoal.monthlyMinutes"
    private static let notifiedMonthKey = "playtimeGoal.notifiedMonth"
    private static let pickedAppIDKey = "playtimeGoal.pickedBacklogAppID"
    private static let pickedDateKey = "playtimeGoal.pickedBacklogDate"
    /// How long a backlog pick stays "current" before a fresh visit rerolls
    /// it automatically.
    private static let rerollInterval: TimeInterval = 60 * 60 * 24 * 7

    var monthlyGoalMinutes: Int? {
        didSet { UserDefaults.standard.set(monthlyGoalMinutes, forKey: Self.goalMinutesKey) }
    }

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = caches.appendingPathComponent("Mist", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheFileURL = dir.appendingPathComponent("play-sessions.json")

        if let data = try? Data(contentsOf: cacheFileURL),
           let stored = try? JSONDecoder().decode([PlaySession].self, from: data) {
            sessions = stored
        }
        monthlyGoalMinutes = UserDefaults.standard.object(forKey: Self.goalMinutesKey) as? Int
        pickedBacklogAppID = UserDefaults.standard.object(forKey: Self.pickedAppIDKey) as? Int
        pickedBacklogDate = UserDefaults.standard.object(forKey: Self.pickedDateKey) as? Date
    }

    // MARK: - Playtime goal

    var minutesLoggedThisMonth: Int {
        let calendar = Calendar.current
        return sessions
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.minutes }
    }

    /// Called by RunningGameMonitor when a play session ends. Also checks
    /// whether this session just pushed the month over the goal, notifying
    /// once per month rather than again on every session after it's hit.
    func logSession(minutes: Int) {
        guard minutes > 0 else { return }
        sessions.append(PlaySession(date: Date(), minutes: minutes))
        // Keep the last 4 months — plenty for "this month" plus any
        // boundary rollover, without growing the file forever.
        let cutoff = Calendar.current.date(byAdding: .month, value: -4, to: Date()) ?? .distantPast
        sessions.removeAll { $0.date < cutoff }
        saveSessions()

        guard let monthlyGoalMinutes, minutesLoggedThisMonth >= monthlyGoalMinutes else { return }
        let monthKey = Self.monthKey(for: Date())
        guard UserDefaults.standard.string(forKey: Self.notifiedMonthKey) != monthKey else { return }
        UserDefaults.standard.set(monthKey, forKey: Self.notifiedMonthKey)
        NotificationService.shared.notifyPlaytimeGoalReached(minutes: minutesLoggedThisMonth)
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            try? data.write(to: cacheFileURL)
        }
    }

    private static func monthKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    // MARK: - Backlog pick

    /// The persisted pick, if it's still within the reroll window and still
    /// present in the current backlog (owned, un-played). Callers fall back
    /// to a fresh random pick when this is nil.
    func currentBacklogPick(in backlog: [GameLibraryItem]) -> GameLibraryItem? {
        guard let pickedBacklogAppID, let pickedBacklogDate,
              Date().timeIntervalSince(pickedBacklogDate) < Self.rerollInterval else {
            return nil
        }
        return backlog.first { $0.appID == pickedBacklogAppID }
    }

    func setBacklogPick(_ item: GameLibraryItem?) {
        pickedBacklogAppID = item?.appID
        pickedBacklogDate = item == nil ? nil : Date()
        UserDefaults.standard.set(pickedBacklogAppID, forKey: Self.pickedAppIDKey)
        UserDefaults.standard.set(pickedBacklogDate, forKey: Self.pickedDateKey)
    }
}

struct PlaySession: Codable {
    let date: Date
    let minutes: Int
}
