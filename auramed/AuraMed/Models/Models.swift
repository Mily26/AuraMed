import Foundation
import SwiftData

// MARK: - Enums

enum MedForm: String, Codable, CaseIterable, Identifiable {
    case capsula, comprimido, perla, jarabe, gotas, inyectable
    var id: String { rawValue }

    var title: String {
        switch self {
        case .capsula: "Cápsula"
        case .comprimido: "Comprimido"
        case .perla: "Perla"
        case .jarabe: "Jarabe"
        case .gotas: "Gotas"
        case .inyectable: "Inyectable"
        }
    }

    var symbol: String {
        switch self {
        case .capsula: "capsule.portrait"
        case .comprimido: "minus.circle"
        case .perla: "oval"
        case .jarabe: "waterbottle"
        case .gotas: "drop"
        case .inyectable: "syringe"
        }
    }

    func unit(_ count: Int) -> String {
        let one = count == 1
        switch self {
        case .capsula: return one ? "cápsula" : "cápsulas"
        case .comprimido: return one ? "comprimido" : "comprimidos"
        case .perla: return one ? "perla" : "perlas"
        case .jarabe: return "ml"
        case .gotas: return one ? "gota" : "gotas"
        case .inyectable: return one ? "dosis" : "dosis"
        }
    }
}

enum MedCategory: String, Codable, CaseIterable, Identifiable {
    case recetado, suplemento, puntual
    var id: String { rawValue }
    var title: String {
        switch self {
        case .recetado: "Recetado"
        case .suplemento: "Suplemento"
        case .puntual: "Puntual"
        }
    }
    var plural: String {
        switch self {
        case .recetado: "Recetados"
        case .suplemento: "Suplementos"
        case .puntual: "Puntuales"
        }
    }
}

enum Frequency: String, Codable, CaseIterable, Identifiable {
    case diario, diasFijos, aDemanda
    var id: String { rawValue }
    var title: String {
        switch self {
        case .diario: "Diario"
        case .diasFijos: "Días fijos"
        case .aDemanda: "A demanda"
        }
    }
}

enum IntakeContext: String, Codable, CaseIterable, Identifiable {
    case conAlimentos, enAyunas, antesDeDormir, conAgua
    var id: String { rawValue }
    var title: String {
        switch self {
        case .conAlimentos: "Con alimentos"
        case .enAyunas: "En ayunas"
        case .antesDeDormir: "Antes de dormir"
        case .conAgua: "Con abundante agua"
        }
    }
    var symbol: String {
        switch self {
        case .conAlimentos: "fork.knife"
        case .enAyunas: "drop"
        case .antesDeDormir: "moon"
        case .conAgua: "takeoutbag.and.cup.and.straw"
        }
    }
}

enum DoseStatus: String, Codable {
    case taken, skipped, snoozed
}

// MARK: - Models

@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    /// Optional short description of the unit, e.g. "blanco", "blanda dorada".
    var detail: String = ""
    var formRaw: String = MedForm.capsula.rawValue
    var categoryRaw: String = MedCategory.suplemento.rawValue
    var frequencyRaw: String = Frequency.diario.rawValue
    var dosePerIntake: Int = 1
    /// Scheduled times as minutes from midnight, sorted.
    var times: [Int] = []
    /// Calendar weekdays (1 = domingo … 7 = sábado) used when frequency is `diasFijos`.
    var weekdays: [Int] = []
    var contextsRaw: [String] = []
    var refillAlert: Bool = true
    var stock: Int = 0
    /// Units in a full pack — reference for the stock bar.
    var stockCapacity: Int = 0
    var prescriber: String = ""
    var isActive: Bool = true
    var refillSnoozedUntil: Date?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \DoseLog.medication)
    var logs: [DoseLog]? = []

    init(name: String) {
        self.name = name
    }

    var form: MedForm {
        get { MedForm(rawValue: formRaw) ?? .capsula }
        set { formRaw = newValue.rawValue }
    }
    var category: MedCategory {
        get { MedCategory(rawValue: categoryRaw) ?? .suplemento }
        set { categoryRaw = newValue.rawValue }
    }
    var frequency: Frequency {
        get { Frequency(rawValue: frequencyRaw) ?? .diario }
        set { frequencyRaw = newValue.rawValue }
    }
    var contexts: [IntakeContext] {
        get { contextsRaw.compactMap(IntakeContext.init(rawValue:)) }
        set { contextsRaw = newValue.map(\.rawValue) }
    }

    /// "1 comprimido blanco"
    var doseDescription: String {
        let base = "\(dosePerIntake) \(form.unit(dosePerIntake))"
        return detail.isEmpty ? base : "\(base) \(detail)"
    }

    var contextDescription: String {
        contexts.first?.title ?? ""
    }

    /// Average units consumed per day (nil for on-demand).
    var unitsPerDay: Double? {
        switch frequency {
        case .diario: return Double(dosePerIntake * times.count)
        case .diasFijos: return Double(dosePerIntake * times.count * weekdays.count) / 7
        case .aDemanda: return nil
        }
    }

    var daysRemaining: Int? {
        guard let perDay = unitsPerDay, perDay > 0 else { return nil }
        return Int((Double(stock) / perDay).rounded(.down))
    }

    var stockRatio: Double {
        let cap = max(stockCapacity, stock, 1)
        return min(1, Double(stock) / Double(cap))
    }

    var needsRefill: Bool {
        guard isActive, refillAlert, let days = daysRemaining else { return false }
        if let until = refillSnoozedUntil, until > .now { return false }
        return days <= 7
    }
}

@Model
final class DoseLog {
    var id: UUID = UUID()
    var medication: Medication?
    /// Start of the day this dose belongs to.
    var day: Date = Date()
    /// Scheduled slot in minutes from midnight.
    var slot: Int = 0
    var statusRaw: String = DoseStatus.taken.rawValue
    var takenAt: Date?
    var snoozedUntil: Date?
    /// Logged outside of the schedule ("¿Toma fuera de hora?").
    var isExtra: Bool = false

    init(medication: Medication, day: Date, slot: Int, status: DoseStatus) {
        self.medication = medication
        self.day = Calendar.current.startOfDay(for: day)
        self.slot = slot
        self.statusRaw = status.rawValue
    }

    var status: DoseStatus {
        get { DoseStatus(rawValue: statusRaw) ?? .taken }
        set { statusRaw = newValue.rawValue }
    }

    var scheduledDate: Date {
        Calendar.current.date(byAdding: .minute, value: slot, to: day) ?? day
    }

    /// Taken more than an hour after the scheduled time.
    var isLate: Bool {
        guard status == .taken, !isExtra, let takenAt else { return false }
        return takenAt.timeIntervalSince(scheduledDate) > 3600
    }
}
