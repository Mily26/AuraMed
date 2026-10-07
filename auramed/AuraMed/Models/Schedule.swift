import Foundation

/// Chronobiological windows used to group the day's doses.
enum DayPeriod: Int, CaseIterable, Identifiable {
    case manana, tarde, noche
    var id: Int { rawValue }

    init(slot: Int) {
        switch slot {
        case ..<720: self = .manana     // < 12:00
        case ..<1140: self = .tarde     // < 19:00
        default: self = .noche
        }
    }

    var title: String {
        switch self {
        case .manana: "Mañana"
        case .tarde: "Tarde"
        case .noche: "Noche"
        }
    }

    var symbol: String {
        switch self {
        case .manana: "sunrise"
        case .tarde: "sun.max"
        case .noche: "moon"
        }
    }
}

enum DoseState: Equatable {
    case taken(late: Bool)
    case skipped
    case dueNow
    case snoozed(until: Date)
    case upcoming
    case missed
    case future
}

struct ScheduledDose: Identifiable {
    let medication: Medication
    let day: Date
    let slot: Int
    let log: DoseLog?
    let state: DoseState

    var id: String { "\(medication.id.uuidString)-\(slot)-\(day.timeIntervalSince1970)" }
    var period: DayPeriod { DayPeriod(slot: slot) }
    var date: Date { Calendar.current.date(byAdding: .minute, value: slot, to: day) ?? day }

    var isTaken: Bool {
        if case .taken = state { return true }
        return false
    }
}

enum Schedule {
    static var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = Locale(identifier: "es_ES")
        return cal
    }

    /// Minutes before the slot when a dose becomes "Tomar ahora".
    static let dueWindowBefore = 30

    static func isScheduled(_ med: Medication, on day: Date) -> Bool {
        let cal = calendar
        guard med.isActive else { return false }
        let start = cal.startOfDay(for: day)
        guard start >= cal.startOfDay(for: med.createdAt) else { return false }
        switch med.frequency {
        case .diario: return true
        case .diasFijos: return med.weekdays.contains(cal.component(.weekday, from: start))
        case .aDemanda: return false
        }
    }

    static func doses(for day: Date, medications: [Medication], now: Date = .now) -> [ScheduledDose] {
        let cal = calendar
        let start = cal.startOfDay(for: day)
        let today = cal.startOfDay(for: now)
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)

        var result: [ScheduledDose] = []
        for med in medications where isScheduled(med, on: start) {
            let dayLogs = (med.logs ?? []).filter { cal.isDate($0.day, inSameDayAs: start) && !$0.isExtra }
            let createdToday = cal.isDate(med.createdAt, inSameDayAs: start)
            let createdMinutes = cal.component(.hour, from: med.createdAt) * 60 + cal.component(.minute, from: med.createdAt)
            for slot in med.times.sorted() {
                let log = dayLogs.first { $0.slot == slot }
                // Doses before the moment the reminder was created don't count (unless logged).
                if createdToday, slot < createdMinutes - dueWindowBefore, log == nil { continue }
                let state: DoseState
                if let log, log.status == .taken {
                    state = .taken(late: log.isLate)
                } else if let log, log.status == .skipped {
                    state = .skipped
                } else if start < today {
                    state = .missed
                } else if start > today {
                    state = .future
                } else if let log, log.status == .snoozed, let until = log.snoozedUntil, until > now {
                    state = .snoozed(until: until)
                } else if nowMinutes >= slot - dueWindowBefore {
                    state = .dueNow
                } else {
                    state = .upcoming
                }
                result.append(ScheduledDose(medication: med, day: start, slot: slot, log: log, state: state))
            }
        }
        return result.sorted { ($0.slot, $0.medication.name) < ($1.slot, $1.medication.name) }
    }

    static func extraLogs(for day: Date, medications: [Medication]) -> [DoseLog] {
        let start = calendar.startOfDay(for: day)
        return medications
            .flatMap { $0.logs ?? [] }
            .filter { calendar.isDate($0.day, inSameDayAs: start) && $0.isExtra }
            .sorted { ($0.takenAt ?? .distantPast) < ($1.takenAt ?? .distantPast) }
    }

    // MARK: Adherence

    struct Adherence {
        var expected = 0
        var taken = 0
        var late = 0
        var skipped = 0
        var missed: Int { max(0, expected - taken) }
        var ratio: Double { expected == 0 ? 0 : Double(taken) / Double(expected) }
        var percent: Int { Int((ratio * 100).rounded()) }
    }

    /// Adherence counting only doses whose time has already arrived (or that were taken).
    static func adherence(from: Date, to: Date, medications: [Medication], now: Date = .now) -> Adherence {
        let cal = calendar
        var result = Adherence()
        var day = cal.startOfDay(for: from)
        let last = min(cal.startOfDay(for: to), cal.startOfDay(for: now))
        while day <= last {
            for dose in doses(for: day, medications: medications, now: now) {
                switch dose.state {
                case .taken(let late):
                    result.expected += 1
                    result.taken += 1
                    if late { result.late += 1 }
                case .skipped:
                    result.expected += 1
                    result.skipped += 1
                case .missed:
                    result.expected += 1
                case .dueNow, .snoozed:
                    if dose.date <= now { result.expected += 1 }
                case .upcoming, .future:
                    break
                }
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// Whether every dose of a day was taken (nil if nothing was scheduled).
    static func dayComplete(_ day: Date, medications: [Medication], now: Date = .now) -> Bool? {
        let list = doses(for: day, medications: medications, now: now)
        guard !list.isEmpty else { return nil }
        return list.allSatisfy(\.isTaken)
    }

    /// Consecutive complete days ending today (today counts only once completed).
    static func streak(medications: [Medication], now: Date = .now) -> Int {
        let cal = calendar
        var count = 0
        var day = cal.startOfDay(for: now)
        if dayComplete(day, medications: medications, now: now) == true { count += 1 }
        for _ in 0..<366 {
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
            if let earliest = medications.map(\.createdAt).min(), day < cal.startOfDay(for: earliest) { break }
            switch dayComplete(day, medications: medications, now: now) {
            case .some(true): count += 1
            case .some(false): return count
            case .none: continue
            }
        }
        return count
    }

    // MARK: Formatting

    static func timeString(_ slot: Int) -> String {
        String(format: "%02d:%02d", slot / 60, slot % 60)
    }

    static func timeStringAMPM(_ slot: Int) -> String {
        let h = slot / 60, m = slot % 60
        let h12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "%02d:%02d %@", h12, m, h < 12 ? "AM" : "PM")
    }

    static func minutes(from date: Date) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    static func date(fromMinutes minutes: Int) -> Date {
        calendar.date(byAdding: .minute, value: minutes, to: calendar.startOfDay(for: .now)) ?? .now
    }
}
