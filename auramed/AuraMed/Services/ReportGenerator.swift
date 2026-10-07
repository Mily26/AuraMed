import SwiftUI

/// Builds a one-page clinical summary PDF on device (nothing leaves the phone unless the
/// user shares it).
@MainActor
enum ReportGenerator {
    static func makePDF(medications: [Medication], patient: String) -> URL? {
        let url = URL.temporaryDirectory.appending(path: "AuraMed-Informe-\(Date.now.localDayKey).pdf")
        let page = ReportPage(medications: medications.filter { $0.frequency != .aDemanda || !($0.logs ?? []).isEmpty },
                              patient: patient)
            .frame(width: 595, height: 842)
        let renderer = ImageRenderer(content: page)
        renderer.proposedSize = ProposedViewSize(width: 595, height: 842)

        var ok = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
            ok = true
        }
        return ok ? url : nil
    }
}

private struct ReportPage: View {
    var medications: [Medication]
    var patient: String

    private var monthStart: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
    }
    private var thirtyDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -29, to: .now) ?? .now
    }

    var body: some View {
        let total = Schedule.adherence(from: thirtyDaysAgo, to: .now, medications: medications)
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                LogoMark(lineWidth: 2).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aura Med").font(.serif(24))
                    Text("Informe de adherencia · últimos 30 días").font(.sans(11)).foregroundStyle(Aura.onSurfaceVariant)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if !patient.isEmpty { Text(patient).font(.sans(12, .semibold)) }
                    Text(Date.now.formatted(date: .long, time: .omitted)).font(.sans(11)).foregroundStyle(Aura.onSurfaceVariant)
                }
            }
            Rectangle().fill(Aura.outlineVariant).frame(height: 0.5)

            HStack(spacing: 12) {
                stat("Adherencia", "\(total.percent)%")
                stat("Tomas registradas", "\(total.taken) / \(total.expected)")
                stat("Tardías (+1h)", "\(total.late)")
                stat("Omitidas", "\(total.missed)")
            }

            Text("Tratamientos").font(.serif(18))
            VStack(spacing: 0) {
                row(["Tratamiento", "Dosis", "Horario", "Contexto", "Adherencia"], header: true)
                ForEach(medications) { med in
                    let a = Schedule.adherence(from: thirtyDaysAgo, to: .now, medications: [med])
                    row([
                        med.name,
                        med.doseDescription,
                        med.frequency == .aDemanda ? "A demanda" : med.times.map(Schedule.timeString).joined(separator: ", "),
                        med.contexts.map(\.title).joined(separator: ", "),
                        a.expected == 0 ? "—" : "\(a.percent)% (\(a.taken)/\(a.expected))",
                    ], header: false)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Aura.outlineVariant, lineWidth: 0.5))

            Spacer()
            Text("Documento generado por el paciente con Aura Med a partir de sus registros personales. No sustituye la valoración de un profesional sanitario.")
                .font(.sans(9))
                .foregroundStyle(Aura.onSurfaceVariant)
        }
        .padding(40)
        .foregroundStyle(Aura.onSurface)
        .background(Color.white)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.sans(8, .bold)).foregroundStyle(Aura.onSurfaceVariant)
            Text(value).font(.serif(20))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Aura.surfaceLow))
    }

    private func row(_ cells: [String], header: Bool) -> some View {
        // Column widths sum to the 515pt content width minus padding/spacing.
        let widths: [CGFloat] = [130, 90, 70, 90, 65]
        return HStack(alignment: .top, spacing: 8) {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, text in
                Text(text)
                    .font(.sans(9, header ? .bold : .regular))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: widths[min(i, widths.count - 1)], alignment: .leading)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(header ? Aura.surfaceContainer : Color.white)
    }
}
