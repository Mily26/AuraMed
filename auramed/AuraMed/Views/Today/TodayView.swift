import SwiftUI
import SwiftData

struct TodayView: View {
    @Binding var showProfile: Bool
    @Binding var showNew: Bool

    @EnvironmentObject private var profile: Profile
    @Query(sort: \Medication.createdAt) private var medications: [Medication]
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var showExtra = false
    @State private var editing: Medication?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let doses = Schedule.doses(for: selectedDay, medications: medications, now: now)
            let extras = Schedule.extraLogs(for: selectedDay, medications: medications)

            ScrollView {
                VStack(alignment: .leading, spacing: Aura.spaceLG) {
                    greeting
                    WeekRibbon(selected: $selectedDay, medications: medications, now: now)
                    if medications.isEmpty {
                        EmptyStateCard(
                            symbol: "leaf",
                            title: "Tu ritual empieza aquí",
                            message: "Añade tu primer medicamento o suplemento y te recordaremos cada toma con calma.",
                            actionTitle: "Añadir al botiquín"
                        ) { showNew = true }
                    } else {
                        RitualSummaryCard(doses: doses, day: selectedDay, now: now)
                        if doses.isEmpty {
                            restDay
                        }
                        ForEach(DayPeriod.allCases) { period in
                            let items = doses.filter { $0.period == period }
                            if !items.isEmpty {
                                PeriodSection(period: period, doses: items, onEdit: { editing = $0 })
                            }
                        }
                        if !extras.isEmpty {
                            ExtraSection(logs: extras)
                        }
                        OffScheduleCard { showExtra = true }
                    }
                }
                .padding(.horizontal, Aura.margin)
                .padding(.top, Aura.spaceSM)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeader(subtitle: "Hoy", showProfile: $showProfile)
        }
        .sheet(isPresented: $showExtra) {
            ExtraDoseSheet(medications: medications.filter(\.isActive), day: selectedDay)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(Aura.radiusLG)
        }
        .fullScreenCover(item: $editing) { med in
            ScheduleFormView(medication: med)
        }
    }

    private var greeting: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.greeting)
                    .font(.serif(24, .medium))
                    .foregroundStyle(Aura.onSurface)
                Text("Respira, hidrátate y cuida tu tiempo.")
                    .font(.bodyMD)
                    .foregroundStyle(Aura.onSurfaceVariant)
            }
            Spacer()
            HydrationButton()
        }
        .padding(.top, 4)
    }

    private var restDay: some View {
        HStack(spacing: Aura.spaceMD) {
            Image(systemName: "moon.stars")
                .font(.system(size: 20))
                .foregroundStyle(Aura.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Aura.surfaceLowest))
            VStack(alignment: .leading, spacing: 2) {
                Text("Día de pausa").font(.headlineSM).foregroundStyle(Aura.onSurface)
                Text("No hay tomas programadas para este día.").font(.bodySM).foregroundStyle(Aura.onSurfaceVariant)
            }
            Spacer()
        }
        .auraCard()
    }
}

// MARK: - Hydration

struct HydrationButton: View {
    @State private var glasses = 0
    private var key: String { "water-" + Date.now.localDayKey }

    var body: some View {
        Button {
            glasses += 1
            UserDefaults.standard.set(glasses, forKey: key)
        } label: {
            Image(systemName: "drop.fill")
                .font(.system(size: 18))
                .foregroundStyle(Aura.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Aura.surfaceContainer))
                .overlay(alignment: .topTrailing) {
                    if glasses > 0 {
                        Text("\(glasses)")
                            .font(.sans(10, .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Circle().fill(Aura.primary))
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            Button("Reiniciar vasos de hoy", systemImage: "arrow.counterclockwise") {
                glasses = 0
                UserDefaults.standard.set(0, forKey: key)
            }
        }
        .accessibilityLabel("Registrar un vaso de agua. \(glasses) hoy")
        .onAppear { glasses = UserDefaults.standard.integer(forKey: key) }
    }
}

// MARK: - Week ribbon

struct WeekRibbon: View {
    @Binding var selected: Date
    var medications: [Medication]
    var now: Date

    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        return (-7...7).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(days, id: \.self) { day in
                        cell(day).id(day)
                    }
                }
                .padding(.horizontal, Aura.margin)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Aura.margin)
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
        }
    }

    private func cell(_ day: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(day, inSameDayAs: selected)
        let isPast = day < cal.startOfDay(for: now)
        let complete = Schedule.dayComplete(day, medications: medications, now: now)
        let dot: Color = {
            if isSelected { return Aura.primaryFixed }
            if complete == true { return Aura.primary }
            if isPast, complete == false { return Aura.secondaryContainer }
            return Aura.outlineVariant.opacity(0.7)
        }()

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) { selected = day }
        } label: {
            VStack(spacing: 6) {
                Text(day.esDayShort)
                    .font(.sans(12, isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Aura.surface.opacity(0.85) : Aura.onSurfaceVariant)
                Text("\(cal.component(.day, from: day))")
                    .font(.sans(17, isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? Aura.surface : Aura.onSurface)
                Circle().fill(dot).frame(width: 6, height: 6)
            }
            .frame(width: 54, height: isSelected ? 84 : 78)
            .background(
                RoundedRectangle(cornerRadius: Aura.radiusLG, style: .continuous)
                    .fill(isSelected ? Aura.onSurface : Aura.surfaceLow)
            )
            .shadow(color: isSelected ? Aura.onSurface.opacity(0.18) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Summary

struct RitualSummaryCard: View {
    var doses: [ScheduledDose]
    var day: Date
    var now: Date

    var body: some View {
        let taken = doses.filter(\.isTaken).count
        let total = doses.count
        let ratio = total == 0 ? 0 : Double(taken) / Double(total)
        let isToday = Calendar.current.isDate(day, inSameDayAs: now)

        HStack(spacing: Aura.spaceMD) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isToday ? "RITUAL DE HOY" : "RITUAL DEL \(day.es("EEEEdMMMM").uppercased())")
                    .font(.labelSM).tracking(1)
                    .foregroundStyle(Aura.primary)
                Text(total == 0 ? "Sin tomas programadas" : "\(taken) de \(total) tomas completadas")
                    .font(.serif(21))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Aura.onSurface)
                Label(message(ratio: ratio, total: total), systemImage: "leaf.fill")
                    .font(.bodyMD)
                    .foregroundStyle(Aura.onSurfaceVariant)
                    .labelStyle(TightLabelStyle(iconColor: Aura.primary))
            }
            Spacer(minLength: 0)
            ProgressRing(progress: ratio, size: 66, lineWidth: 5)
        }
        .padding(.vertical, 6)
        .auraCard()
    }

    private func message(ratio: Double, total: Int) -> String {
        switch ratio {
        case _ where total == 0: "Un día para descansar"
        case 1: "Ritual completo, bien hecho"
        case 0.5...: "Tu cuerpo fluye en armonía"
        case 0.01...: "Paso a paso, sin prisa"
        default: "Cada toma es una pausa para ti"
        }
    }
}

struct TightLabelStyle: LabelStyle {
    var iconColor: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.foregroundStyle(iconColor).font(.system(size: 13))
            configuration.title
        }
    }
}

// MARK: - Sections

struct PeriodSection: View {
    var period: DayPeriod
    var doses: [ScheduledDose]
    var onEdit: (Medication) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: period.symbol)
                        .font(.system(size: 18))
                        .foregroundStyle(iconColor)
                    Text(period.title)
                        .font(.sans(21, .medium))
                        .foregroundStyle(Aura.onSurface)
                }
                Spacer()
                Text("\(Schedule.timeStringAMPM(doses.first?.slot ?? 0)) • \(status.text)")
                    .font(.sans(12, .semibold))
                    .foregroundStyle(status.color)
            }
            .padding(.horizontal, 4)

            ForEach(doses) { dose in
                DoseCard(dose: dose, onEdit: onEdit)
            }
        }
    }

    private var iconColor: Color {
        switch period {
        case .manana: Aura.onSurface
        case .tarde: Aura.secondary
        case .noche: Aura.onSurface
        }
    }

    private var status: (text: String, color: Color) {
        if doses.allSatisfy(\.isTaken) { return ("Completado", Aura.onSurface) }
        if let due = doses.first(where: { $0.state == .dueNow }) {
            return (Date.now.timeIntervalSince(due.date) > 3600 ? "Atrasada" : "En hora", Aura.secondary)
        }
        if doses.contains(where: { $0.state == .missed }) { return ("Omitida", Aura.secondary) }
        if doses.contains(where: { if case .snoozed = $0.state { return true }; return false }) { return ("En pausa", Aura.secondary) }
        return ("Pendiente", Aura.onSurface)
    }
}

struct DoseCard: View {
    var dose: ScheduledDose
    var onEdit: (Medication) -> Void

    private var med: Medication { dose.medication }

    var body: some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: Aura.radiusLG))
            .contextMenu { menu }
            .animation(.easeInOut(duration: 0.3), value: dose.state)
    }

    @ViewBuilder private var content: some View {
        switch dose.state {
        case .taken(let late):
            HStack(spacing: Aura.spaceMD) {
                MedIcon(form: med.form, fill: Aura.surfaceLowest, tint: Aura.primary, size: 54)
                info(extra: late ? "Tomada tarde" : nil)
                Spacer(minLength: 0)
                Button {
                    withAnimation { DoseActions.undo(med, day: dose.day, slot: dose.slot) }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Aura.primary))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Tomada. Toca para deshacer")
            }
            .auraCard(Aura.primaryFixed.opacity(0.28))

        case .dueNow, .snoozed:
            VStack(alignment: .leading, spacing: Aura.spaceMD) {
                HStack(spacing: Aura.spaceMD) {
                    MedIcon(form: med.form, fill: Aura.secondaryFixed.opacity(0.7), tint: Aura.secondary, size: 54)
                    info(extra: snoozeText)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    Button {
                        withAnimation { DoseActions.take(med, day: dose.day, slot: dose.slot) }
                    } label: {
                        Label("Tomar ahora", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(PrimaryPillButtonStyle())

                    if case .dueNow = dose.state {
                        Button("Pausar 30m") {
                            withAnimation { DoseActions.snooze(med, day: dose.day, slot: dose.slot) }
                        }
                        .buttonStyle(SecondaryPillButtonStyle())
                    }
                }
            }
            .auraCard()

        case .missed, .skipped:
            HStack(spacing: Aura.spaceMD) {
                MedIcon(form: med.form, fill: Aura.surfaceContainer, tint: Aura.onSurfaceVariant.opacity(0.7), size: 54)
                info(extra: dose.state == .skipped ? "Omitida" : "Sin registrar")
                Spacer(minLength: 0)
                Button {
                    withAnimation { DoseActions.take(med, day: dose.day, slot: dose.slot, at: dose.date) }
                } label: {
                    Text("Registrar")
                        .font(.sans(13, .semibold))
                        .foregroundStyle(Aura.onSurface)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Capsule().fill(Aura.surfaceLowest))
                }
                .buttonStyle(PressableStyle())
            }
            .auraCard()
            .opacity(0.9)

        case .upcoming, .future:
            HStack(spacing: Aura.spaceMD) {
                MedIcon(form: med.form, fill: Aura.surfaceContainer, tint: Aura.onSurfaceVariant, size: 54)
                info(extra: nil)
                Spacer(minLength: 0)
                Button {
                    withAnimation { DoseActions.take(med, day: dose.day, slot: dose.slot) }
                } label: {
                    Circle()
                        .stroke(Aura.outlineVariant, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PressableStyle())
                .disabled(dose.state == .future)
                .accessibilityLabel("Marcar como tomada")
            }
            .auraCard()
        }
    }

    private var snoozeText: String? {
        if case .snoozed(let until) = dose.state {
            return "En pausa hasta \(until.formatted(date: .omitted, time: .shortened))"
        }
        return nil
    }

    private func info(extra: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                nameText.lineLimit(1).fixedSize()
                nameText.lineLimit(1).minimumScaleFactor(0.85)
                nameText.lineLimit(2)
            }
            let context = extra ?? (med.contextDescription.isEmpty ? nil : med.contextDescription)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    doseText.fixedSize()
                    if let context {
                        Circle().fill(Aura.outlineVariant).frame(width: 4, height: 4)
                        contextText(context).fixedSize()
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    doseText
                    if let context { contextText(context) }
                }
            }
        }
    }

    private var nameText: some View {
        Text(med.name)
            .font(.serif(21))
            .foregroundStyle(Aura.onSurface)
    }

    private var doseText: some View {
        Text(med.doseDescription)
            .font(.bodyMD)
            .foregroundStyle(Aura.onSurfaceVariant)
            .lineLimit(1)
    }

    private func contextText(_ text: String) -> some View {
        Text(text)
            .font(.sans(12, .semibold))
            .foregroundStyle(text == med.contextDescription ? Aura.tertiary : Aura.secondary)
            .lineLimit(1)
    }

    @ViewBuilder private var menu: some View {
        if !dose.isTaken, dose.state != .future {
            Button("Tomar ahora", systemImage: "checkmark.circle") {
                DoseActions.take(med, day: dose.day, slot: dose.slot)
            }
        }
        if dose.state == .dueNow || dose.state == .upcoming {
            Button("Pausar 30 minutos", systemImage: "clock.arrow.circlepath") {
                DoseActions.snooze(med, day: dose.day, slot: dose.slot)
            }
        }
        if dose.state != .skipped, dose.state != .future {
            Button("Omitir esta toma", systemImage: "forward") {
                DoseActions.skip(med, day: dose.day, slot: dose.slot)
            }
        }
        if dose.log != nil {
            Button("Deshacer registro", systemImage: "arrow.uturn.backward") {
                DoseActions.undo(med, day: dose.day, slot: dose.slot)
            }
        }
        Divider()
        Button("Editar recordatorio", systemImage: "slider.horizontal.3") { onEdit(med) }
    }
}

struct ExtraSection: View {
    var logs: [DoseLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil").font(.system(size: 17))
                Text("Tomas adicionales").font(.sans(21, .medium))
            }
            .foregroundStyle(Aura.onSurface)
            .padding(.horizontal, 4)

            ForEach(logs) { log in
                if let med = log.medication {
                    HStack(spacing: Aura.spaceMD) {
                        MedIcon(form: med.form, fill: Aura.surfaceLowest, tint: Aura.primary, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(med.name).font(.serif(20)).foregroundStyle(Aura.onSurface)
                            Text("\(med.doseDescription) · \(log.takenAt?.formatted(date: .omitted, time: .shortened) ?? "")")
                                .font(.bodySM).foregroundStyle(Aura.onSurfaceVariant)
                        }
                        Spacer()
                    }
                    .auraCard(Aura.primaryFixed.opacity(0.2))
                    .contextMenu {
                        Button("Eliminar registro", systemImage: "trash", role: .destructive) {
                            DoseActions.deleteExtra(log)
                        }
                    }
                }
            }
        }
    }
}

struct OffScheduleCard: View {
    var action: () -> Void

    var body: some View {
        HStack(spacing: Aura.spaceMD) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 18))
                .foregroundStyle(Aura.secondary)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Aura.secondaryFixed.opacity(0.8)))
            VStack(alignment: .leading, spacing: 2) {
                Text("¿Otra hora?")
                    .font(.serif(20, .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(Aura.onSurface)
                Text("Registra una toma pasada o extra")
                    .font(.bodySM)
                    .foregroundStyle(Aura.onSurfaceVariant)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button("Anotar", action: action)
                .font(.sans(14, .semibold))
                .foregroundStyle(Aura.onSurface)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Capsule().fill(Aura.surfaceLowest))
                .buttonStyle(PressableStyle())
        }
        .auraCard(Aura.surfaceLow)
        .padding(.top, Aura.spaceSM)
    }
}

// MARK: - Extra dose sheet

struct ExtraDoseSheet: View {
    var medications: [Medication]
    var day: Date

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Medication?
    @State private var time = Date.now
    /// Scheduled slot this dose fulfils; nil = additional dose outside the schedule.
    @State private var slot: Int?
    @State private var userPickedSlot = false

    /// Scheduled doses of the selected medication still pending on this day.
    private var pendingSlots: [Int] {
        guard let selected else { return [] }
        return Schedule.doses(for: day, medications: [selected])
            .filter { !$0.isTaken }
            .map(\.slot)
    }

    private var takenDate: Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: day)
        comps.hour = cal.component(.hour, from: time)
        comps.minute = cal.component(.minute, from: time)
        return cal.date(from: comps) ?? time
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Aura.spaceLG) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ANOTACIÓN").font(.labelSM).tracking(1).foregroundStyle(Aura.secondary)
                    Text("Registrar una toma").font(.headlineLG).foregroundStyle(Aura.onSurface)
                }

                if medications.isEmpty {
                    Text("Aún no tienes medicamentos en tu botiquín.")
                        .font(.bodyMD).foregroundStyle(Aura.onSurfaceVariant)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("¿Qué tomaste?").font(.sans(15, .medium)).foregroundStyle(Aura.onSurface)
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(medications) { med in
                                    Chip(title: med.name, symbol: med.form.symbol, selected: selected?.id == med.id, selectedFill: Aura.primary) {
                                        selected = med
                                        userPickedSlot = false
                                        suggestSlot()
                                    }
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }

                    HStack {
                        Text("Hora de la toma").font(.sans(15, .medium)).foregroundStyle(Aura.onSurface)
                        Spacer()
                        DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    .auraCard(Aura.surfaceContainer, radius: Aura.radiusMD)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("¿A qué toma corresponde?").font(.sans(15, .medium)).foregroundStyle(Aura.onSurface)
                        FlowLayout(spacing: 8) {
                            ForEach(pendingSlots, id: \.self) { s in
                                Chip(title: "\(Schedule.timeString(s)) · \(DayPeriod(slot: s).title)",
                                     symbol: "clock", selected: slot == s, selectedFill: Aura.primary) {
                                    slot = s
                                    userPickedSlot = true
                                }
                            }
                            Chip(title: "Toma adicional", symbol: "plus", selected: slot == nil, selectedFill: Aura.secondary) {
                                slot = nil
                                userPickedSlot = true
                            }
                        }
                        Text(slot == nil
                             ? "Se guardará aparte, sin cubrir ninguna toma programada."
                             : "Se marcará como tomada la toma de las \(Schedule.timeString(slot ?? 0)).")
                            .font(.bodySM).foregroundStyle(Aura.onSurfaceVariant)
                    }
                }

                Button {
                    if let selected {
                        if let slot {
                            DoseActions.take(selected, day: day, slot: slot, at: takenDate)
                        } else {
                            DoseActions.logExtra(selected, at: takenDate)
                        }
                    }
                    dismiss()
                } label: {
                    Label("Guardar toma", systemImage: "heart")
                }
                .buttonStyle(PrimaryPillButtonStyle())
                .disabled(selected == nil)
                .opacity(selected == nil ? 0.5 : 1)
                .padding(.top, Aura.spaceSM)
            }
            .padding(Aura.spaceLG)
        }
        .background(Aura.surface)
        .onAppear {
            selected = medications.first { med in
                !Schedule.doses(for: day, medications: [med]).filter { !$0.isTaken }.isEmpty
            } ?? medications.first
            suggestSlot()
        }
        .onChange(of: time) { _, _ in
            if !userPickedSlot { suggestSlot() }
        }
    }

    /// Preselect the pending scheduled dose closest to the chosen time.
    private func suggestSlot() {
        let minutes = Schedule.minutes(from: time)
        slot = pendingSlots.min { abs($0 - minutes) < abs($1 - minutes) }
    }
}
