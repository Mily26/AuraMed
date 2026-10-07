import Foundation
import SwiftData

/// Single on-device SwiftData container (no iCloud, no network): everything lives in the
/// app's sandbox on the iPhone.
@MainActor
enum Store {
    static let container: ModelContainer = {
        let schema = Schema([Medication.self, DoseLog.self])
        let config = ModelConfiguration("AuraMed", schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("No se pudo abrir el almacenamiento local: \(error)")
        }
    }()

    static var context: ModelContext { container.mainContext }

    static func allMedications() -> [Medication] {
        (try? context.fetch(FetchDescriptor<Medication>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    static func medication(id: UUID) -> Medication? {
        var d = FetchDescriptor<Medication>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }
}

/// All mutations of doses go through here so stock and reminders stay in sync.
@MainActor
enum DoseActions {
    static func take(_ med: Medication, day: Date, slot: Int, at date: Date = .now) {
        let log = existingLog(med, day: day, slot: slot) ?? insertLog(med, day: day, slot: slot)
        let wasTaken = log.status == .taken
        log.status = .taken
        log.takenAt = date
        log.snoozedUntil = nil
        if !wasTaken { consumeStock(med) }
        commit()
    }

    static func skip(_ med: Medication, day: Date, slot: Int) {
        let log = existingLog(med, day: day, slot: slot) ?? insertLog(med, day: day, slot: slot)
        if log.status == .taken { restoreStock(med) }
        log.status = .skipped
        log.takenAt = nil
        commit()
    }

    static func undo(_ med: Medication, day: Date, slot: Int) {
        guard let log = existingLog(med, day: day, slot: slot) else { return }
        if log.status == .taken { restoreStock(med) }
        Store.context.delete(log)
        commit()
    }

    static func snooze(_ med: Medication, day: Date, slot: Int, minutes: Int = 30) {
        let log = existingLog(med, day: day, slot: slot) ?? insertLog(med, day: day, slot: slot)
        guard log.status != .taken else { return }
        let until = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        log.status = .snoozed
        log.snoozedUntil = until
        commit()
        NotificationManager.shared.scheduleSnooze(for: med, slot: slot, at: until)
    }

    /// "¿Toma fuera de hora?" — a dose logged outside of the schedule.
    static func logExtra(_ med: Medication, at date: Date) {
        let log = DoseLog(medication: med, day: date, slot: Schedule.minutes(from: date), status: .taken)
        log.takenAt = date
        log.isExtra = true
        Store.context.insert(log)
        consumeStock(med)
        commit()
    }

    static func deleteExtra(_ log: DoseLog) {
        if let med = log.medication { restoreStock(med) }
        Store.context.delete(log)
        commit()
    }

    static func refill(_ med: Medication, units: Int) {
        med.stock += units
        med.stockCapacity = max(med.stockCapacity, med.stock)
        med.refillSnoozedUntil = nil
        commit()
    }

    static func postponeRefill(_ med: Medication, days: Int = 2) {
        med.refillSnoozedUntil = Calendar.current.date(byAdding: .day, value: days, to: .now)
        commit()
    }

    // MARK: Helpers

    private static func existingLog(_ med: Medication, day: Date, slot: Int) -> DoseLog? {
        (med.logs ?? []).first {
            !$0.isExtra && $0.slot == slot && Calendar.current.isDate($0.day, inSameDayAs: day)
        }
    }

    private static func insertLog(_ med: Medication, day: Date, slot: Int) -> DoseLog {
        let log = DoseLog(medication: med, day: day, slot: slot, status: .snoozed)
        Store.context.insert(log)
        return log
    }

    private static func consumeStock(_ med: Medication) {
        med.stock = max(0, med.stock - med.dosePerIntake)
        if med.needsRefill, let days = med.daysRemaining, days <= 3 {
            NotificationManager.shared.notifyRefill(for: med)
        }
    }

    private static func restoreStock(_ med: Medication) {
        med.stock += med.dosePerIntake
    }

    static func commit() {
        try? Store.context.save()
        NotificationManager.shared.reschedule()
    }
}
