import SwiftUI
import SwiftData

struct ScheduleFormView: View {
    /// nil → create a new medication.
    var medication: Medication?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notifications: NotificationManager

    @State private var name = ""
    @State private var detail = ""
    @State private var form: MedForm = .capsula
    @State private var category: MedCategory = .suplemento
    @State private var dose = 1
    @State private var frequency: Frequency = .diario
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var times: [TimeEntry] = [TimeEntry(minutes: 510), TimeEntry(minutes: 1290)]
    @State private var contexts: Set<IntakeContext> = [.conAlimentos]
    @State private var refillAlert = true
    @State private var stockText = "60"
    @State private var prescriber = ""
    @State private var confirmDelete = false
    @State private var loaded = false

    @FocusState private var focused: Field?
    private enum Field { case name, detail, stock, prescriber }

    private let suggestions = ["Probiótico Digest", "Omega 3 Puro", "Vitamina D3", "Magnesio", "Hierro"]
    private var isEditing: Bool { medication != nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (frequency == .aDemanda || !times.isEmpty)
            && (frequency != .diasFijos || !weekdays.isEmpty)
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: Aura.spaceLG) {
                    intro
                    ritualCard
                    nameField
                    categoryPicker
                    formGrid
                    doseAndFrequency
                    if frequency != .aDemanda { timesSection }
                    contextSection
                    refillSection
                    actions
                }
                .padding(.horizontal, Aura.margin)
                .padding(.top, Aura.spaceSM)
                .padding(.bottom, Aura.spaceXL)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Aura.surface.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") { focused = nil }
            }
        }
        .onAppear(perform: load)
        .confirmationDialog("¿Eliminar \(medication?.name ?? "")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar del botiquín", role: .destructive, action: delete)
        } message: {
            Text("También se borrará su historial de tomas de este iPhone.")
        }
    }

    // MARK: Sections

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Aura.onSurface)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Volver")
            LogoTile(size: 36)
            Text(isEditing ? "Editar Recordatorio" : "Nuevo Recordatorio")
                .font(.serif(22))
                .foregroundStyle(Aura.onSurface)
            Spacer()
            AvatarView(size: 36)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isEditing ? "AJUSTAR REGISTRO" : "NUEVO REGISTRO")
                .font(.labelMD).tracking(1)
                .foregroundStyle(Aura.secondary)
            Text(isEditing ? "Cuidar tu rutina" : "Añadir al botiquín")
                .font(.serif(34))
                .foregroundStyle(Aura.onSurface)
            Text("Configura tu dosis y horario con calma para mantener tu ritmo diario sin prisas.")
                .font(.bodyLG)
                .foregroundStyle(Aura.onSurfaceVariant)
        }
    }

    private var ritualCard: some View {
        HStack(spacing: Aura.spaceMD) {
            ZStack {
                Circle().fill(Aura.primaryFixed.opacity(0.6))
                LogoMark(lineWidth: 2.2).padding(12)
            }
            .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text("RITUAL DE CUIDADO").font(.labelSM).tracking(0.8).foregroundStyle(Aura.primary)
                Text("Bienestar consciente").font(.serif(21, .medium)).foregroundStyle(Aura.onSurface)
                Text("Cada toma es una pausa para ti").font(.bodySM).foregroundStyle(Aura.onSurfaceVariant)
            }
            Spacer(minLength: 0)
        }
        .auraCard(Aura.surfaceContainer)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Nombre de la toma")
            HStack {
                TextField("Ej. Ashwagandha KSM-66", text: $name)
                    .font(.bodyLG)
                    .foregroundStyle(Aura.onSurface)
                    .focused($focused, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focused = .detail }
                Image(systemName: "leaf").foregroundStyle(Aura.onSurfaceVariant)
            }
            .inputField(focused: focused == .name)

            HStack(spacing: 8) {
                TextField("Descripción opcional (ej. blanco, sublingual)", text: $detail)
                    .font(.bodyMD)
                    .focused($focused, equals: .detail)
            }
            .inputField(focused: focused == .detail, compact: true)

            if !isEditing {
                FlowLayout(spacing: 6) {
                    Text("Sugerencias:")
                        .font(.sans(12, .semibold))
                        .foregroundStyle(Aura.onSurface)
                        .padding(.vertical, 6)
                    ForEach(suggestions, id: \.self) { s in
                        Button(s) { name = s }
                            .font(.sans(13))
                            .foregroundStyle(Aura.onSurface)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Aura.surfaceHigh))
                            .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Tipo")
            HStack(spacing: 8) {
                ForEach(MedCategory.allCases) { c in
                    Chip(title: c.title, selected: category == c, selectedFill: Aura.primary) { category = c }
                }
            }
        }
    }

    private var formGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                label("Forma y presentación")
                Spacer()
                Text(form.title).font(.sans(13, .medium)).foregroundStyle(Aura.primary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(MedForm.allCases) { f in
                    let selected = form == f
                    Button { withAnimation(.easeInOut(duration: 0.2)) { form = f } } label: {
                        VStack(spacing: 8) {
                            Image(systemName: f.symbol).font(.system(size: 20))
                            Text(f.title).font(.sans(13, selected ? .semibold : .regular))
                        }
                        .foregroundStyle(selected ? .white : Aura.onSurface)
                        .frame(maxWidth: .infinity)
                        .frame(height: 76)
                        .background(RoundedRectangle(cornerRadius: 4).fill(selected ? Aura.primary : Aura.surfaceHigh))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var doseAndFrequency: some View {
        VStack(alignment: .leading, spacing: Aura.spaceMD) {
            HStack {
                Text("Dosis por toma").font(.sans(16, .medium)).foregroundStyle(Aura.onSurface)
                Spacer()
                HStack(spacing: 18) {
                    Button { dose = max(1, dose - 1) } label: { Image(systemName: "minus") }
                    Text("\(dose)").font(.sans(20, .semibold)).frame(minWidth: 22)
                    Button { dose = min(99, dose + 1) } label: { Image(systemName: "plus") }
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Aura.onSurface)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Capsule().fill(Aura.surfaceLowest))
            }
            Text("\(dose) \(form.unit(dose)) cada vez")
                .font(.bodySM).foregroundStyle(Aura.onSurfaceVariant)
                .padding(.top, -10)

            VStack(alignment: .leading, spacing: 8) {
                Text("Frecuencia").font(.bodyMD).foregroundStyle(Aura.onSurface)
                HStack(spacing: 6) {
                    ForEach(Frequency.allCases) { f in
                        let selected = frequency == f
                        Button { withAnimation(.easeInOut(duration: 0.2)) { frequency = f } } label: {
                            Text(f.title)
                                .font(.sans(14, selected ? .semibold : .regular))
                                .foregroundStyle(Aura.onSurface)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(RoundedRectangle(cornerRadius: 4).fill(selected ? Aura.surfaceLowest : Aura.surfaceHigh))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if frequency == .diasFijos {
                    weekdayPicker.padding(.top, 6)
                }
                if frequency == .aDemanda {
                    Text("Sin recordatorios: registra cada toma cuando la necesites desde Hoy o el Botiquín.")
                        .font(.bodySM).foregroundStyle(Aura.onSurfaceVariant)
                }
            }
        }
        .auraCard(Aura.surfaceContainer, radius: Aura.radiusLG, padding: Aura.spaceMD + 4)
    }

    private var weekdayPicker: some View {
        // Monday-first order with Calendar weekday numbers.
        let days: [(Int, String)] = [(2, "L"), (3, "M"), (4, "X"), (5, "J"), (6, "V"), (7, "S"), (1, "D")]
        return HStack(spacing: 6) {
            ForEach(days, id: \.0) { day, letter in
                let on = weekdays.contains(day)
                Button {
                    if on { weekdays.remove(day) } else { weekdays.insert(day) }
                } label: {
                    Text(letter)
                        .font(.sans(14, .semibold))
                        .foregroundStyle(on ? .white : Aura.onSurface)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Circle().fill(on ? Aura.primary : Aura.surfaceLowest))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var timesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                label("Horarios programados")
                Spacer()
                Text("Zona horaria local").font(.bodySM).foregroundStyle(Aura.onSurfaceVariant)
            }
            ForEach($times) { $entry in
                let id = entry.id
                TimeRow(minutes: $entry.minutes) {
                    withAnimation { times.removeAll { $0.id == id } }
                }
            }
            Button {
                withAnimation {
                    let next = min(23 * 60 + 30, (times.map(\.minutes).max() ?? 420) + 240)
                    times.append(TimeEntry(minutes: next))
                }
            } label: {
                Label("Añadir otra toma", systemImage: "plus")
                    .font(.sans(14, .medium))
                    .foregroundStyle(Aura.onSurface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Aura.surfaceHigh))
            }
            .buttonStyle(PressableStyle())
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Momento y contexto de ingesta")
            FlowLayout(spacing: 8) {
                ForEach(IntakeContext.allCases) { c in
                    let on = contexts.contains(c)
                    Button {
                        if on { contexts.remove(c) } else { contexts.insert(c) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: c.symbol).font(.system(size: 13))
                            Text(c.title).font(.sans(14, on ? .medium : .regular))
                        }
                        .foregroundStyle(Aura.onSurface)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Capsule().fill(on ? Aura.primaryFixed.opacity(0.8) : Aura.surfaceHigh))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var refillSection: some View {
        VStack(alignment: .leading, spacing: Aura.spaceMD) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "archivebox")
                    .font(.system(size: 18))
                    .foregroundStyle(Aura.secondary)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aviso de reposición").font(.sans(16, .medium)).foregroundStyle(Aura.onSurface)
                    Text("Te recordaremos recargar con serenidad").font(.bodySM).foregroundStyle(Aura.onSurfaceVariant)
                }
                Spacer()
                Toggle("", isOn: $refillAlert)
                    .labelsHidden()
                    .tint(Aura.primary)
            }
            HStack {
                Text("Dosis actuales en frasco").font(.bodyMD).foregroundStyle(Aura.onSurface)
                Spacer()
                TextField("0", text: $stockText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.sans(18, .medium))
                    .focused($focused, equals: .stock)
                    .frame(width: 80)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Aura.surfaceLowest))
                Text("unidades").font(.bodySM).foregroundStyle(Aura.onSurfaceVariant)
            }
            HStack {
                Image(systemName: "stethoscope").foregroundStyle(Aura.onSurfaceVariant)
                TextField("Médico o pauta (opcional)", text: $prescriber)
                    .font(.bodyMD)
                    .focused($focused, equals: .prescriber)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 4).fill(Aura.surfaceLowest))
        }
        .auraCard(Aura.surfaceContainer, radius: Aura.radiusLG, padding: Aura.spaceMD + 4)
    }

    private var actions: some View {
        VStack(spacing: Aura.spaceMD) {
            Button(action: save) {
                Label(isEditing ? "Guardar cambios" : "Guardar en botiquín", systemImage: "heart")
                    .font(.sans(18, .semibold))
            }
            .buttonStyle(PrimaryPillButtonStyle())
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.5)
            .shadow(color: Aura.primary.opacity(0.2), radius: 12, y: 6)

            if isEditing {
                Button("Eliminar del botiquín", role: .destructive) { confirmDelete = true }
                    .font(.sans(15, .medium))
                    .foregroundStyle(Aura.secondary)
            } else {
                Button("Descartar") { dismiss() }
                    .font(.sans(15, .medium))
                    .foregroundStyle(Aura.onSurfaceVariant)
            }
        }
        .padding(.top, Aura.spaceSM)
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.sans(16, .medium)).foregroundStyle(Aura.onSurface)
    }

    // MARK: Persistence

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let m = medication else { return }
        name = m.name
        detail = m.detail
        form = m.form
        category = m.category
        dose = m.dosePerIntake
        frequency = m.frequency
        weekdays = Set(m.weekdays)
        times = m.times.map { TimeEntry(minutes: $0) }
        contexts = Set(m.contexts)
        refillAlert = m.refillAlert
        stockText = "\(m.stock)"
        prescriber = m.prescriber
    }

    private func save() {
        let med = medication ?? Medication(name: "")
        med.name = name.trimmingCharacters(in: .whitespaces)
        med.detail = detail.trimmingCharacters(in: .whitespaces)
        med.form = form
        med.category = category
        med.dosePerIntake = dose
        med.frequency = frequency
        med.weekdays = weekdays.sorted()
        med.times = Array(Set(times.map(\.minutes))).sorted()
        med.contexts = IntakeContext.allCases.filter(contexts.contains)
        med.refillAlert = refillAlert
        let stock = Int(stockText.filter(\.isNumber)) ?? 0
        if stock != med.stock || medication == nil {
            med.stock = stock
            med.stockCapacity = max(stock, medication == nil ? stock : med.stockCapacity)
        }
        med.prescriber = prescriber.trimmingCharacters(in: .whitespaces)
        if medication == nil {
            Store.context.insert(med)
        }
        DoseActions.commit()
        if notifications.authorization == .notDetermined {
            Task { await notifications.requestAuthorization() }
        }
        dismiss()
    }

    private func delete() {
        guard let medication else { return }
        Store.context.delete(medication)
        DoseActions.commit()
        dismiss()
    }
}

// MARK: - Time row

private struct TimeEntry: Identifiable {
    let id = UUID()
    var minutes: Int
}

private struct TimeRow: View {
    @Binding var minutes: Int
    var onRemove: () -> Void

    var body: some View {
        let period = DayPeriod(slot: minutes)
        HStack(spacing: 12) {
            Image(systemName: period == .manana ? "sun.max" : period == .tarde ? "sun.haze" : "moon")
                .font(.system(size: 18))
                .foregroundStyle(period == .noche ? Aura.secondary : Aura.primary)
            DatePicker("", selection: Binding(
                get: { Schedule.date(fromMinutes: minutes) },
                set: { minutes = Schedule.minutes(from: $0) }
            ), displayedComponents: .hourAndMinute)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "es_ES"))
            Text(period.title).font(.bodyMD).foregroundStyle(Aura.onSurfaceVariant)
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Aura.onSurfaceVariant)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Eliminar horario")
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 4).fill(Aura.surfaceHigh))
    }
}

// MARK: - Helpers

private extension View {
    func inputField(focused: Bool, compact: Bool = false) -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, compact ? 12 : 16)
            .background(RoundedRectangle(cornerRadius: 4).fill(Aura.surfaceHigh))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(focused ? Aura.primary : Aura.onSurface.opacity(0.06), lineWidth: 1)
            )
    }
}

/// Simple wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
