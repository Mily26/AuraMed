import SwiftUI
import SwiftData

struct ProgressScreen: View {
    @Binding var showProfile: Bool
    @Query(sort: \Medication.createdAt) private var medications: [Medication]
    @EnvironmentObject private var profile: Profile
    @State private var weekOffset = 0
    @State private var shareURL: URL?

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "es_ES")
        c.firstWeekday = 2
        return c
    }

    private var monthStart: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
    }

    private var scheduledMeds: [Medication] {
        medications
            .filter { $0.frequency != .aDemanda }
            .sorted { ($0.times.min() ?? 0, $0.name) < ($1.times.min() ?? 0, $1.name) }
    }

    var body: some View {
        let month = Schedule.adherence(from: monthStart, to: .now, medications: medications)
        let streak = Schedule.streak(medications: medications)

        ScrollView {
            VStack(alignment: .leading, spacing: Aura.spaceLG) {
                if scheduledMeds.isEmpty {
                    EmptyStateCard(
                        symbol: "chart.bar",
                        title: "Tu constancia aparecerá aquí",
                        message: "Cuando programes tus tomas verás tu ritmo semanal, tu racha y el desglose por tratamiento.",
                        actionTitle: nil, action: nil
                    )
                } else {
                    MonthlySummaryCard(adherence: month, streak: streak)
                    weekRhythm
                    breakdown(month: month)
                }
                reportCard
            }
            .padding(.horizontal, Aura.margin)
            .padding(.top, Aura.spaceSM)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeader(subtitle: "Progreso", showProfile: $showProfile)
        }
        .sheet(item: Binding(get: { shareURL.map(ShareItem.init) }, set: { shareURL = $0?.url })) { item in
            ShareSheet(items: [item.url])
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: Week rhythm

    private var weekDays: [Date] {
        let today = cal.startOfDay(for: .now)
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let start = cal.date(byAdding: .weekOfYear, value: weekOffset, to: startOfWeek) ?? startOfWeek
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var weekRhythm: some View {
        let letters = ["L", "M", "X", "J", "V", "S", "D"]
        let today = cal.startOfDay(for: .now)

        return VStack(alignment: .leading, spacing: Aura.spaceMD) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ritmo de la semana").font(.sans(18, .medium)).foregroundStyle(Aura.onSurface)
                    Text("Tomas a tiempo frente a descansos").font(.bodySM).foregroundStyle(Aura.onSurfaceVariant)
                }
                Spacer()
                HStack(spacing: 6) {
                    Button { weekOffset -= 1 } label: { Image(systemName: "chevron.left") }
                    Text(weekOffset == 0 ? "Esta semana" : weekOffset == -1 ? "Semana pasada" : "Hace \(-weekOffset) sem.")
                        .font(.sans(13))
                        .frame(minWidth: 84)
                    Button { weekOffset += 1 } label: { Image(systemName: "chevron.right") }
                        .disabled(weekOffset >= 0)
                        .opacity(weekOffset >= 0 ? 0.3 : 1)
                }
                .font(.sans(13, .medium))
                .foregroundStyle(Aura.onSurface)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                    let a = Schedule.adherence(from: day, to: day, medications: medications)
                    let isFuture = day > today
                    let kind: BarKind = {
                        if isFuture || a.expected == 0 { return .empty }
                        if a.taken == 0 { return .missed }
                        if a.late > 0 || a.taken < a.expected { return .late }
                        return .onTime
                    }()
                    VStack(spacing: 8) {
                        WeekBar(ratio: a.expected == 0 ? 0 : a.ratio, kind: kind, isToday: cal.isDate(day, inSameDayAs: today))
                            .frame(height: 140)
                        Text(letters[index]).font(.sans(11, .semibold)).foregroundStyle(Aura.onSurfaceVariant)
                        Circle()
                            .fill(kind == .onTime ? Aura.primary : kind == .late ? Aura.secondary : Aura.outlineVariant)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)

            HStack(spacing: 18) {
                legend(Aura.primary, "Puntual")
                legend(Aura.secondaryContainer, "Tardía (+1h)")
                legend(Aura.surfaceHighest, "Omitida")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .auraCard(Aura.surfaceContainer, padding: Aura.spaceMD + 4)
        .animation(.easeInOut(duration: 0.3), value: weekOffset)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.sans(12)).foregroundStyle(Aura.onSurfaceVariant)
        }
    }

    // MARK: Breakdown

    private func breakdown(month: Schedule.Adherence) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Desglose por tratamiento", trailing: "\(scheduledMeds.filter(\.isActive).count) activos")
            ForEach(scheduledMeds) { med in
                let a = Schedule.adherence(from: monthStart, to: .now, medications: [med])
                TreatmentRow(medication: med, adherence: a)
            }
        }
    }

    // MARK: Report

    private var reportCard: some View {
        VStack(spacing: Aura.spaceMD) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 20))
                .foregroundStyle(Aura.primary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Aura.surfaceLowest))
            Text("Tu informe para el especialista")
                .font(.serif(22))
                .foregroundStyle(Aura.onSurface)
                .multilineTextAlignment(.center)
            Text("Sintetiza tus horarios, tomas omitidas y adherencia en un documento estructurado.")
                .font(.bodyMD)
                .foregroundStyle(Aura.onSurfaceVariant)
                .multilineTextAlignment(.center)
            Button {
                shareURL = ReportGenerator.makePDF(medications: medications, patient: profile.name)
            } label: {
                Label("Exportar reporte clínico en PDF", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryPillButtonStyle())
            .disabled(scheduledMeds.isEmpty)
            .opacity(scheduledMeds.isEmpty ? 0.5 : 1)

            Label("Tus datos se guardan solo en este iPhone", systemImage: "lock")
                .font(.sans(11, .medium))
                .foregroundStyle(Aura.onSurfaceVariant)
        }
        .padding(Aura.spaceLG)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Aura.radiusLG).fill(Aura.surfaceContainer))
    }
}

// MARK: - Pieces

struct MonthlySummaryCard: View {
    var adherence: Schedule.Adherence
    var streak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Aura.spaceMD) {
            HStack {
                Text("RESUMEN MENSUAL").font(.labelSM).tracking(1).foregroundStyle(Aura.onSurfaceVariant)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame").font(.system(size: 11))
                    Text(streak == 1 ? "1 día seguido" : "\(streak) días seguidos").font(.sans(12, .medium))
                }
                .foregroundStyle(Aura.primary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Aura.primaryFixed.opacity(0.6)))
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Tu constancia este mes")
                    .font(.serif(28))
                    .foregroundStyle(Aura.onSurface)
                Spacer()
                Text("\(adherence.percent)%")
                    .font(.serif(30))
                    .foregroundStyle(Aura.onSurface)
            }
            Text(message)
                .font(.bodyMD)
                .foregroundStyle(Aura.onSurfaceVariant)
            HStack(spacing: 12) {
                CapsuleBar(value: adherence.ratio, height: 6)
                Text("\(adherence.taken) / \(adherence.expected) tomas")
                    .font(.sans(12, .medium))
                    .foregroundStyle(Aura.onSurface)
                    .fixedSize()
            }
        }
        .padding(Aura.spaceLG)
        .background(alignment: .bottomTrailing) {
            ZStack(alignment: .bottomTrailing) {
                Aura.surfaceLowest
                Circle()
                    .stroke(Aura.surfaceLow, lineWidth: 18)
                    .frame(width: 130, height: 130)
                    .offset(x: 55, y: 40)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Aura.radiusLG, style: .continuous))
        .floatingShadow()
    }

    private var message: String {
        guard adherence.expected > 0 else { return "Tu primer registro marcará el inicio de tu ritmo." }
        switch adherence.percent {
        case 95...: return "Excelente consistencia. Tu rutina se mantiene en un equilibrio sereno y reparador."
        case 80..<95: return "Muy buen ritmo. Pequeños ajustes de horario pueden ayudarte a llegar más lejos."
        case 50..<80: return "Vas construyendo tu hábito. Considera activar recordatorios con sonido."
        default: return "Cada día es un nuevo comienzo. Empieza por la toma que te resulte más sencilla."
        }
    }
}

enum BarKind { case onTime, late, missed, empty }

struct WeekBar: View {
    var ratio: Double
    var kind: BarKind
    var isToday: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isToday ? Aura.surfaceHighest : Aura.surfaceHigh)
                if kind == .onTime || kind == .late {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(kind == .onTime ? Aura.primary : Aura.secondaryContainer)
                        .frame(height: max(16, (geo.size.height - (isToday ? 8 : 0)) * ratio))
                        .padding(isToday ? 4 : 0)
                }
            }
        }
        .frame(maxWidth: 38)
        .animation(.easeInOut(duration: 0.4), value: ratio)
    }
}

struct TreatmentRow: View {
    var medication: Medication
    var adherence: Schedule.Adherence

    var body: some View {
        let med = medication
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                MedIcon(form: med.form, fill: Aura.surfaceContainer, tint: Aura.secondary, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(med.name).font(.serif(22)).foregroundStyle(Aura.onSurface).lineLimit(2)
                    Text("\(med.doseDescription) • \(med.times.map(Schedule.timeString).joined(separator: ", "))")
                        .font(.bodySM).foregroundStyle(Aura.onSurfaceVariant).lineLimit(1)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(adherence.expected == 0 ? "—" : "\(adherence.percent)%")
                        .font(.sans(20, .semibold)).foregroundStyle(Aura.onSurface)
                    Text("\(adherence.taken) de \(adherence.expected)")
                        .font(.sans(11)).foregroundStyle(Aura.onSurfaceVariant)
                }
            }
            CapsuleBar(value: adherence.ratio, height: 5)
            HStack {
                Label(note, systemImage: noteIcon)
                    .font(.bodySM)
                    .foregroundStyle(Aura.onSurfaceVariant)
                    .lineLimit(1)
                Spacer()
                Text(rating).font(.sans(11, .semibold)).foregroundStyle(Aura.onSurface)
            }
        }
        .padding(Aura.spaceMD + 2)
        .background(RoundedRectangle(cornerRadius: Aura.radiusLG).fill(Aura.surfaceLowest))
        .overlay(RoundedRectangle(cornerRadius: Aura.radiusLG).stroke(Aura.hairline))
    }

    private var note: String {
        if adherence.expected == 0 { return "Aún sin tomas este mes" }
        if adherence.missed > 0 {
            return adherence.missed == 1 ? "1 dosis omitida este mes" : "\(adherence.missed) dosis omitidas este mes"
        }
        if adherence.late > 0 {
            return adherence.late == 1 ? "1 toma tardía este mes" : "\(adherence.late) tomas tardías este mes"
        }
        return "Sin retrasos registrados este mes"
    }

    private var noteIcon: String {
        adherence.missed > 0 ? "moon" : adherence.late > 0 ? "clock" : "checkmark.circle"
    }

    private var rating: String {
        guard adherence.expected > 0 else { return "" }
        switch adherence.percent {
        case 100 where adherence.late == 0: return "Impecable"
        case 95...: return "Muy alto"
        case 85...: return "Bueno"
        case 60...: return "Regular"
        default: return "Mejorable"
        }
    }
}

// MARK: - Share

struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
