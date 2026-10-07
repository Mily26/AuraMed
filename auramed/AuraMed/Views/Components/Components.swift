import SwiftUI

// MARK: - Header

struct AppHeader<Trailing: View>: View {
    var subtitle: String
    @Binding var showProfile: Bool
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Aura.spaceSM) {
            LogoTile(size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Aura Med")
                    .font(.serif(22))
                    .foregroundStyle(Aura.onSurface)
                Text(subtitle.uppercased())
                    .font(.labelSM)
                    .tracking(1)
                    .foregroundStyle(Aura.onSurfaceVariant)
            }
            .padding(.leading, 4)
            Spacer()
            trailing
            Button { showProfile = true } label: {
                AvatarView(size: 36)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Perfil y ajustes")
        }
        .padding(.horizontal, Aura.margin)
        .padding(.vertical, 10)
        .background(
            Aura.surface.opacity(0.88)
                .background(.ultraThinMaterial)
                .shadow(color: Aura.onSurface.opacity(0.03), radius: 6, y: 1)
                .ignoresSafeArea(edges: .top)
        )
    }
}

extension AppHeader where Trailing == QuietToggle {
    init(subtitle: String, showProfile: Binding<Bool>) {
        self.init(subtitle: subtitle, showProfile: showProfile) { QuietToggle() }
    }
}

/// "Recordatorios silenciosos" — the spa icon in the header toggles sound-free reminders.
struct QuietToggle: View {
    @AppStorage(NotificationManager.quietKey) private var quiet = false

    var body: some View {
        Button {
            quiet.toggle()
            NotificationManager.shared.reschedule()
        } label: {
            Image(systemName: quiet ? "camera.macro.circle.fill" : "camera.macro")
                .font(.system(size: 19))
                .foregroundStyle(quiet ? Aura.primary : Aura.onSurfaceVariant)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(quiet ? "Recordatorios silenciosos activados" : "Activar recordatorios silenciosos")
    }
}

struct LogoTile: View {
    var size: CGFloat
    var body: some View {
        LogoMark(lineWidth: 2.4)
            .padding(size * 0.08)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 4).fill(Aura.surfaceHigh))
    }
}

struct AvatarView: View {
    @EnvironmentObject private var profile: Profile
    var size: CGFloat

    var body: some View {
        Group {
            if let img = profile.avatar {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Image("Avatar").resizable().scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Aura.hairline, lineWidth: 1))
    }
}

// MARK: - Progress

struct ProgressRing: View {
    var progress: Double
    var size: CGFloat = 64
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle().stroke(Aura.surfaceHighest, lineWidth: lineWidth * 0.85)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(Aura.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
            Text("\(Int((progress * 100).rounded()))%")
                .font(.sans(13, .bold))
                .foregroundStyle(Aura.onSurface)
        }
        .frame(width: size, height: size)
    }
}

/// Capsule-shaped progress track.
struct CapsuleBar: View {
    var value: Double
    var color: Color = Aura.primary
    var track: Color = Aura.surfaceHighest
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(color)
                    .frame(width: max(height, geo.size.width * min(1, max(0, value))))
                    .opacity(value <= 0 ? 0 : 1)
            }
        }
        .frame(height: height)
        .animation(.easeInOut(duration: 0.5), value: value)
    }
}

// MARK: - Chips & tags

struct Chip: View {
    var title: String
    var symbol: String? = nil
    var selected: Bool
    var selectedFill: Color = Aura.onSurface
    var selectedText: Color = .white
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 12, weight: .medium))
                }
                Text(title).font(.sans(13, .medium))
            }
            .foregroundStyle(selected ? selectedText : Aura.onSurface)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(selected ? selectedFill : Aura.surfaceHigh))
        }
        .buttonStyle(PressableStyle())
    }
}

struct Tag: View {
    var text: String
    var fill: Color = Aura.surfaceHigh
    var foreground: Color = Aura.onSurfaceVariant
    var body: some View {
        Text(text)
            .font(.sans(11, .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(fill))
    }
}

/// Form silhouette inside a soft container.
struct MedIcon: View {
    var form: MedForm
    var fill: Color = Aura.surfaceContainer
    var tint: Color = Aura.onSurfaceVariant
    var size: CGFloat = 48
    var circle = true

    var body: some View {
        Image(systemName: form.symbol)
            .font(.system(size: size * 0.42, weight: .regular))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                Group {
                    if circle { Circle().fill(fill) }
                    else { RoundedRectangle(cornerRadius: size * 0.33, style: .continuous).fill(fill) }
                }
            )
    }
}

struct SectionTitle: View {
    var title: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.serif(22)).foregroundStyle(Aura.onSurface)
            Spacer()
            if let trailing {
                Text(trailing.uppercased())
                    .font(.labelSM).tracking(0.8)
                    .foregroundStyle(Aura.onSurfaceVariant)
            }
        }
    }
}

struct EmptyStateCard: View {
    var symbol: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Aura.spaceMD) {
            Image(systemName: symbol)
                .font(.system(size: 26))
                .foregroundStyle(Aura.primary)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Aura.primaryFixed.opacity(0.5)))
            Text(title)
                .font(.headlineSM)
                .foregroundStyle(Aura.onSurface)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.bodyMD)
                .foregroundStyle(Aura.onSurfaceVariant)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus")
                }
                .buttonStyle(PrimaryPillButtonStyle())
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .auraCard(padding: Aura.spaceLG)
    }
}

extension Date {
    /// "2026-10-01" in the device's time zone.
    var localDayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    var esDayShort: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEE"
        return f.string(from: self).replacingOccurrences(of: ".", with: "").uppercased()
    }

    func es(_ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.setLocalizedDateFormatFromTemplate(format)
        return f.string(from: self)
    }
}
