#if DEBUG
import Foundation
import SwiftData

/// Sample data for previews and screenshots. Only runs in Debug builds launched with
/// the `-seedDemo` argument, and only when the store is empty.
@MainActor
enum DemoData {
    static func seedIfEmpty() {
        guard Store.allMedications().isEmpty else { return }
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -30, to: cal.startOfDay(for: .now))!

        func med(_ name: String, _ detail: String, _ form: MedForm, _ cat: MedCategory, dose: Int, times: [Int],
                 ctx: [IntakeContext], stock: Int, cap: Int, prescriber: String = "", freq: Frequency = .diario) -> Medication {
            let m = Medication(name: name)
            m.detail = detail
            m.form = form
            m.category = cat
            m.dosePerIntake = dose
            m.times = times
            m.contexts = ctx
            m.stock = stock
            m.stockCapacity = cap
            m.prescriber = prescriber
            m.frequency = freq
            m.createdAt = start
            Store.context.insert(m)
            return m
        }

        let meds = [
            med("Levotiroxina 50 mcg", "blanco", .comprimido, .recetado, dose: 1, times: [480], ctx: [.enAyunas], stock: 4, cap: 30, prescriber: "Dra. Claudia Morales"),
            med("Vitamina D3 & K2", "blanda dorada", .capsula, .suplemento, dose: 1, times: [480], ctx: [.conAlimentos], stock: 42, cap: 60, prescriber: "Pauta Nutricional Integrativa"),
            med("Omega 3 Pure EPA/DHA", "de gel", .perla, .suplemento, dose: 2, times: [840], ctx: [.conAlimentos], stock: 36, cap: 90, prescriber: "Dr. Javier Valenzuela"),
            med("Magnesio Bisglicinato", "vegetal", .capsula, .suplemento, dose: 1, times: [1290], ctx: [.antesDeDormir], stock: 28, cap: 30),
            med("Melatonina 1.9 mg", "sublinguales", .gotas, .suplemento, dose: 4, times: [1290], ctx: [.antesDeDormir], stock: 180, cap: 240),
            med("Ibuprofeno 400mg", "", .comprimido, .puntual, dose: 1, times: [], ctx: [.conAlimentos], stock: 16, cap: 20, freq: .aDemanda),
        ]

        var rng = SystemRandomNumberGenerator()
        for offset in 0..<30 {
            let day = cal.date(byAdding: .day, value: offset, to: start)!
            for m in meds where m.frequency == .diario {
                for slot in m.times {
                    let roll = Int.random(in: 0..<100, using: &rng)
                    if roll < 4 { continue } // missed
                    let late = roll < 10
                    let log = DoseLog(medication: m, day: day, slot: slot, status: .taken)
                    log.takenAt = cal.date(byAdding: .minute, value: slot + (late ? 75 : Int.random(in: -10...15, using: &rng)), to: day)
                    Store.context.insert(log)
                }
            }
        }
        // Today: the morning doses are done.
        let today = cal.startOfDay(for: .now)
        for m in meds.prefix(2) {
            let log = DoseLog(medication: m, day: today, slot: 480, status: .taken)
            log.takenAt = cal.date(byAdding: .minute, value: 485, to: today)
            Store.context.insert(log)
        }
        try? Store.context.save()
        if Profile.shared.name.isEmpty { Profile.shared.name = "Elena" }
    }
}
#endif
