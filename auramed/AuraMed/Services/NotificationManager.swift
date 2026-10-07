import Foundation
import UserNotifications

/// Local reminders. Uses a rolling window of individual notifications (next 14 days,
/// up to iOS' 64 pending limit) so doses already taken are never announced, and it is
/// refreshed every time the data changes or the app becomes active.
@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let doseCategory = "DOSE"
    private let takeAction = "TAKE"
    private let snoozeAction = "SNOOZE"
    private let dosePrefix = "dose-"
    private let windowDays = 14
    private let maxPending = 58

    static let quietKey = "quietReminders"

    func configure() {
        center.delegate = self
        let take = UNNotificationAction(identifier: takeAction, title: "Tomar ahora", options: [])
        let snooze = UNNotificationAction(identifier: snoozeAction, title: "Pausar 30 min", options: [])
        let category = UNNotificationCategory(identifier: doseCategory, actions: [take, snooze], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
        Task { await refreshAuthorization() }
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshAuthorization()
        reschedule()
    }

    func refreshAuthorization() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    private var quiet: Bool { UserDefaults.standard.bool(forKey: Self.quietKey) }

    // MARK: Scheduling

    private var rescheduleTask: Task<Void, Never>?

    func reschedule() {
        rescheduleTask?.cancel()
        rescheduleTask = Task { await performReschedule() }
    }

    private func performReschedule() async {
        let medications = Store.allMedications()
        let now = Date.now
        let cal = Schedule.calendar

        struct Slot { let date: Date; var meds: [Medication] }
        var slots: [Date: Slot] = [:]
        for offset in 0..<windowDays {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)) else { continue }
            for dose in Schedule.doses(for: day, medications: medications, now: now) {
                guard dose.date > now else { continue }
                switch dose.state {
                case .taken, .skipped, .snoozed: continue
                default: break
                }
                slots[dose.date, default: Slot(date: dose.date, meds: [])].meds.append(dose.medication)
            }
        }
        let upcoming = slots.values.sorted { $0.date < $1.date }.prefix(maxPending)

        var requests: [UNNotificationRequest] = []
        for slot in upcoming {
            let content = UNMutableNotificationContent()
            content.title = slot.meds.count == 1 ? slot.meds[0].name : "Momento de tu ritual"
            content.body = slot.meds.count == 1
                ? [slot.meds[0].doseDescription, slot.meds[0].contextDescription].filter { !$0.isEmpty }.joined(separator: " · ")
                : slot.meds.map(\.name).joined(separator: ", ")
            content.sound = quiet ? nil : .default
            content.categoryIdentifier = doseCategory
            content.threadIdentifier = "doses"
            content.userInfo = [
                "meds": slot.meds.map(\.id.uuidString),
                "slot": Schedule.minutes(from: slot.date),
                "day": cal.startOfDay(for: slot.date).timeIntervalSince1970,
            ]
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: slot.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = dosePrefix + String(Int(slot.date.timeIntervalSince1970))
            requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }

        let pending = await center.pendingNotificationRequests()
        guard !Task.isCancelled else { return }
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(dosePrefix) })
        for request in requests {
            try? await center.add(request)
        }
    }

    func scheduleSnooze(for med: Medication, slot: Int, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = med.name
        content.body = "Tu pausa terminó. \(med.doseDescription)"
        content.sound = quiet ? nil : .default
        content.categoryIdentifier = doseCategory
        content.userInfo = [
            "meds": [med.id.uuidString],
            "slot": slot,
            "day": Calendar.current.startOfDay(for: .now).timeIntervalSince1970,
        ]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        center.add(UNNotificationRequest(identifier: "snooze-\(med.id.uuidString)-\(slot)", content: content, trigger: trigger))
    }

    func notifyRefill(for med: Medication) {
        let content = UNMutableNotificationContent()
        content.title = "Reposición próxima"
        content.body = "Quedan \(med.stock) \(med.form.unit(med.stock)) de \(med.name). Recarga con serenidad."
        content.sound = quiet ? nil : .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        center.add(UNNotificationRequest(identifier: "refill-\(med.id.uuidString)", content: content, trigger: trigger))
    }

    // MARK: Actions

    fileprivate func handle(action: String, userInfo: [AnyHashable: Any]) {
        guard let ids = userInfo["meds"] as? [String],
              let slot = userInfo["slot"] as? Int,
              let dayInterval = userInfo["day"] as? TimeInterval else { return }
        let day = Date(timeIntervalSince1970: dayInterval)
        for med in ids.compactMap(UUID.init(uuidString:)).compactMap(Store.medication(id:)) {
            switch action {
            case takeAction: DoseActions.take(med, day: day, slot: slot)
            case snoozeAction: DoseActions.snooze(med, day: day, slot: slot)
            default: break
            }
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        let info = response.notification.request.content.userInfo
        Task { @MainActor in
            NotificationManager.shared.handle(action: action, userInfo: info)
            completionHandler()
        }
    }
}
