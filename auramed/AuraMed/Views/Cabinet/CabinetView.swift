import SwiftUI
import SwiftData

struct CabinetView: View {
    @Binding var showProfile: Bool
    @Binding var showNew: Bool

    @Query(sort: \Medication.createdAt) private var medications: [Medication]
    @State private var search = ""
    @State private var filter: MedCategory?
    @State private var editing: Medication?
    @State private var refilling: Medication?
    @Environment(\.openURL) private var openURL

    private var filtered: [Medication] {
        medications
            .filter { filter == nil || $0.category == filter }
            .filter {
                search.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(search)
                    || $0.prescriber.localizedCaseInsensitiveContains(search)
                    || $0.detail.localizedCaseInsensitiveContains(search)
            }
            .sorted { lhs, rhs in
                if lhs.isActive != rhs.isActive { return lhs.isActive }
                return (lhs.daysRemaining ?? .max) < (rhs.daysRemaining ?? .max)
            }
    }

    private var refillCandidate: Medication? {
        medications.filter(\.needsRefill).min { ($0.daysRemaining ?? 0) < ($1.daysRemaining ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Aura.spaceLG) {
                titleBlock
                searchField
                filters

                if medications.isEmpty {
                    EmptyStateCard(
                        symbol: "cross.case",
                        title: "Tu botiquín está vacío",
                        message: "Registra tus medicamentos y suplementos para llevar el control de tu inventario.",
                        actionTitle: "Añadir al botiquín"
                    ) { showNew = true }
                } else {
                    if let med = refillCandidate, filter == nil, search.isEmpty {
                        RefillCard(medication: med,
                                   onPharmacy: { openURL(URL(string: "maps://?q=farmacia")!) },
                                   onRefill: { refilling = med })
                    }
                    if filtered.isEmpty {
                        Text("Sin resultados para “\(search)”")
                            .font(.bodyMD).foregroundStyle(Aura.onSurfaceVariant)
                            .frame(maxWidth: .infinity).padding(.vertical, Aura.spaceLG)
                    }
                    ForEach(filtered) { med in
                        MedicationCard(medication: med,
                                       onEdit: { editing = med },
                                       onRefill: { refilling = med })
                    }
                }

                quote
            }
            .padding(.horizontal, Aura.margin)
            .padding(.top, Aura.spaceSM)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeader(subtitle: "Botiquín", showProfile: $showProfile)
        }
        .fullScreenCover(item: $editing) { med in
            ScheduleFormView(medication: med)
        }
        .sheet(item: $refilling) { med in
            RefillSheet(medication: med)
                .presentationDetents([.height(360)])
                .presentationCornerRadius(Aura.radiusLG)
        }
    }

    private var titleBlock: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("INVENTARIO CONSCIENTE")
                    .font(.labelSM).tracking(1)
                    .foregroundStyle(Aura.onSurfaceVariant)
                Text("Mi Botiquín")
                    .font(.serif(34))
                    .foregroundStyle(Aura.onSurface)
            }
            Spacer()
            let active = medications.filter(\.isActive).count
            let low = medications.filter(\.needsRefill).count
            HStack(spacing: 6) {
                Circle().fill(low > 0 ? Aura.secondary : Aura.primary).frame(width: 6, height: 6)
                Text(low > 0 ? "\(low) por reponer" : "\(active) activos en orden")
                    .font(.sans(12, .medium))
                    .foregroundStyle(Aura.onSurfaceVariant)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Aura.surfaceHigh))
            .padding(.top, 4)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Aura.onSurfaceVariant)
            TextField("Buscar por compuesto, dosis o médico…", text: $search)
                .font(.bodyMD)
                .submitLabel(.search)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Aura.outline)
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 15)
        .background(Capsule().fill(Aura.surfaceLow))
        .overlay(Capsule().stroke(Aura.hairline))
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Chip(title: "Todos (\(medications.count))", selected: filter == nil) { filter = nil }
                ForEach(MedCategory.allCases) { c in
                    let n = medications.filter { $0.category == c }.count
                    if n > 0 || c != .puntual {
                        Chip(title: "\(c.plural) (\(n))", selected: filter == c) { filter = c }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var quote: some View {
        VStack(spacing: 10) {
            Image(systemName: "leaf").foregroundStyle(Aura.primary)
            Text("“Cuidar el cuerpo es un diálogo paciente, no una prisa.”")
                .font(.serif(22).italic())
                .multilineTextAlignment(.center)
                .foregroundStyle(Aura.onSurface)
            Text("Aura Med · Filosofía Botánica")
                .font(.sans(11, .semibold))
                .foregroundStyle(Aura.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Aura.spaceLG)
        .padding(.horizontal, Aura.spaceMD)
        .background(RoundedRectangle(cornerRadius: Aura.radiusLG).fill(Aura.surfaceLow))
        .padding(.top, Aura.spaceSM)
    }
}

// MARK: - Refill alert

struct RefillCard: View {
    var medication: Medication
    var onPharmacy: () -> Void
    var onRefill: () -> Void

    var body: some View {
        let med = medication
        VStack(alignment: .leading, spacing: Aura.spaceMD) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Aura.secondary))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("REPOSICIÓN PRÓXIMA").font(.labelSM).tracking(0.8).foregroundStyle(Aura.secondary)
                        Spacer()
                        Text(daysText).font(.sans(12, .medium)).foregroundStyle(Aura.secondary)
                    }
                    Text(med.name).font(.serif(22, .medium)).foregroundStyle(Aura.onSurface)
                    Text("Solo restan \(med.stock) \(med.form.unit(med.stock)). Te sugerimos reponer con anticipación para no interrumpir tu ritual.")
                        .font(.bodyMD).foregroundStyle(Aura.onSurfaceVariant)
                }
            }
            HStack(spacing: 10) {
                Button(action: onRefill) {
                    Label("Reponer", systemImage: "shippingbox")
                }
                .buttonStyle(PrimaryPillButtonStyle(color: Aura.secondary))

                Button("Posponer 2 días") {
                    withAnimation { DoseActions.postponeRefill(med) }
                }
                .buttonStyle(SecondaryPillButtonStyle(fill: Aura.surfaceLowest))
            }
            Button(action: onPharmacy) {
                Label("Buscar farmacias cercanas", systemImage: "map")
                    .font(.sans(13, .medium))
                    .foregroundStyle(Aura.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .auraCard(Aura.secondaryFixed.opacity(0.55))
    }

    private var daysText: String {
        guard let d = medication.daysRemaining else { return "" }
        return d == 1 ? "Queda 1 día" : "Quedan \(d) días"
    }
}

// MARK: - Medication card

struct MedicationCard: View {
    var medication: Medication
    var onEdit: () -> Void
    var onRefill: () -> Void
    @State private var confirmDelete = false

    var body: some View {
        let med = medication
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                MedIcon(form: med.form, fill: iconFill, tint: iconTint, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Tag(text: med.category.title, fill: tagFill, foreground: tagText)
                        statusLabel
                    }
                    Text(med.name)
                        .font(.serif(22))
                        .foregroundStyle(Aura.onSurface)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.bodySM)
                        .foregroundStyle(Aura.onSurfaceVariant)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                menu
            }

            VStack(spacing: 8) {
                HStack {
                    Text(remainingText).font(.bodyMD).foregroundStyle(Aura.onSurfaceVariant)
                    Spacer()
                    Text("\(med.stock) \(med.form.unit(med.stock))" + (med.stockCapacity > 0 ? " (\(Int(med.stockRatio * 100))%)" : ""))
                        .font(.sans(13, .medium))
                        .foregroundStyle(isCritical ? Aura.secondary : Aura.onSurface)
                }
                CapsuleBar(value: med.stockRatio, color: barColor)
            }

            HStack {
                if !med.prescriber.isEmpty {
                    Label(med.prescriber, systemImage: "stethoscope")
                        .font(.bodySM)
                        .foregroundStyle(Aura.onSurfaceVariant)
                        .lineLimit(1)
                } else {
                    Label(scheduleText, systemImage: "clock")
                        .font(.bodySM)
                        .foregroundStyle(Aura.onSurfaceVariant)
                        .lineLimit(1)
                }
                Spacer()
                footerButton
            }
        }
        .padding(Aura.spaceMD + 2)
        .background(RoundedRectangle(cornerRadius: Aura.radiusLG, style: .continuous).fill(Aura.surfaceLow))
        .overlay(RoundedRectangle(cornerRadius: Aura.radiusLG, style: .continuous).stroke(Aura.hairline))
        .opacity(med.isActive ? 1 : 0.6)
        .confirmationDialog("¿Eliminar \(med.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar del botiquín", role: .destructive) {
                withAnimation {
                    Store.context.delete(med)
                    DoseActions.commit()
                }
            }
        } message: {
            Text("También se borrará su historial de tomas de este iPhone.")
        }
    }

    // MARK: Pieces

    private var isCritical: Bool { medication.needsRefill || (medication.daysRemaining ?? .max) <= 7 }

    private var iconFill: Color {
        if isCritical { return Aura.secondaryFixed.opacity(0.6) }
        switch medication.category {
        case .recetado: return Aura.secondaryFixed.opacity(0.4)
        case .suplemento: return Aura.primaryFixed.opacity(0.55)
        case .puntual: return Aura.surfaceHighest
        }
    }
    private var iconTint: Color { isCritical ? Aura.secondary : Aura.onSurface }
    private var tagFill: Color { medication.category == .recetado ? Aura.secondaryFixed : medication.category == .suplemento ? Aura.primaryFixed.opacity(0.7) : Aura.surfaceHighest }
    private var tagText: Color { medication.category == .recetado ? Aura.onSecondaryContainer : medication.category == .suplemento ? Aura.primary : Aura.onSurfaceVariant }
    private var barColor: Color { isCritical ? Aura.secondary : medication.category == .puntual ? Aura.outline : Aura.primary }

    @ViewBuilder private var statusLabel: some View {
        if !medication.isActive {
            Text("En pausa").font(.sans(11, .medium)).foregroundStyle(Aura.onSurfaceVariant)
        } else if isCritical {
            HStack(spacing: 4) {
                Circle().fill(Aura.secondary).frame(width: 5, height: 5)
                Text("Crítico").font(.sans(11, .medium)).foregroundStyle(Aura.secondary)
            }
        } else if medication.frequency == .aDemanda {
            Text("SOS").font(.sans(11, .medium)).foregroundStyle(Aura.onSurfaceVariant)
        } else {
            Text(medication.stockRatio >= 0.6 ? "Óptimo" : medication.stockRatio >= 0.3 ? "Regular" : "En curso")
                .font(.sans(11, .medium)).foregroundStyle(Aura.onSurfaceVariant)
        }
    }

    private var subtitle: String {
        var parts = [medication.doseDescription]
        if !medication.contextDescription.isEmpty { parts.append(medication.contextDescription.lowercased()) }
        if medication.frequency != .aDemanda, !medication.times.isEmpty {
            parts.append(medication.times.map(Schedule.timeString).joined(separator: " · "))
        }
        return parts.joined(separator: " · ")
    }

    private var scheduleText: String {
        switch medication.frequency {
        case .diario: return medication.times.count == 1 ? "1 vez al día" : "\(medication.times.count) veces al día"
        case .diasFijos: return "\(medication.weekdays.count) días por semana"
        case .aDemanda: return "Según necesidad"
        }
    }

    private var remainingText: String {
        if let d = medication.daysRemaining { return d == 1 ? "Queda 1 día" : "Quedan \(d) días" }
        return "Stock en reserva"
    }

    @ViewBuilder private var footerButton: some View {
        if medication.frequency == .aDemanda {
            smallButton("Registrar toma", "plus") {
                withAnimation { DoseActions.logExtra(medication, at: .now) }
            }
        } else if isCritical {
            smallButton("Reponer", "shippingbox", action: onRefill)
        } else {
            smallButton("Ajustar", "slider.horizontal.3", action: onEdit)
        }
    }

    private func smallButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.sans(12, .semibold))
                .foregroundStyle(Aura.onSurface)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(Aura.surfaceLowest))
        }
        .buttonStyle(PressableStyle())
    }

    private var menu: some View {
        Menu {
            Button("Editar", systemImage: "pencil", action: onEdit)
            Button("Reponer stock", systemImage: "shippingbox", action: onRefill)
            Button(medication.isActive ? "Pausar recordatorios" : "Reactivar", systemImage: medication.isActive ? "pause.circle" : "play.circle") {
                withAnimation {
                    medication.isActive.toggle()
                    DoseActions.commit()
                }
            }
            Divider()
            Button("Eliminar", systemImage: "trash", role: .destructive) { confirmDelete = true }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Aura.onSurface)
                .frame(width: 32, height: 32)
        }
    }
}

// MARK: - Refill sheet

struct RefillSheet: View {
    var medication: Medication
    @Environment(\.dismiss) private var dismiss
    @State private var units = 30

    var body: some View {
        VStack(alignment: .leading, spacing: Aura.spaceLG) {
            VStack(alignment: .leading, spacing: 4) {
                Text("REPONER").font(.labelSM).tracking(1).foregroundStyle(Aura.secondary)
                Text(medication.name).font(.headlineMD).foregroundStyle(Aura.onSurface)
                Text("Actualmente: \(medication.stock) \(medication.form.unit(medication.stock))")
                    .font(.bodyMD).foregroundStyle(Aura.onSurfaceVariant)
            }
            HStack {
                Text("Unidades nuevas").font(.sans(16, .medium))
                Spacer()
                HStack(spacing: 18) {
                    Button { units = max(1, units - (units > 10 ? 5 : 1)) } label: { Image(systemName: "minus") }
                    Text("\(units)").font(.sans(20, .semibold)).frame(minWidth: 40)
                    Button { units += units >= 10 ? 5 : 1 } label: { Image(systemName: "plus") }
                }
                .foregroundStyle(Aura.onSurface)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Capsule().fill(Aura.surfaceLowest))
            }
            .auraCard(Aura.surfaceContainer, radius: Aura.radiusLG)

            Button {
                DoseActions.refill(medication, units: units)
                dismiss()
            } label: {
                Label("Añadir al frasco", systemImage: "shippingbox")
            }
            .buttonStyle(PrimaryPillButtonStyle())
        }
        .padding(Aura.spaceLG)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Aura.surface)
        .onAppear {
            units = max(1, medication.stockCapacity > 0 ? medication.stockCapacity : 30)
        }
    }
}
