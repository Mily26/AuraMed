import SwiftUI

enum AppTab: Hashable {
    case hoy, botiquin, progreso
}

struct RootView: View {
    @State private var tab: AppTab = .hoy
    @State private var showNew = false
    @State private var showProfile = false
    @EnvironmentObject private var notifications: NotificationManager

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .hoy: TodayView(showProfile: $showProfile, showNew: $showNew)
                case .botiquin: CabinetView(showProfile: $showProfile, showNew: $showNew)
                case .progreso: ProgressScreen(showProfile: $showProfile)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Aura.surface.ignoresSafeArea())

            AuraTabBar(selection: $tab) { showNew = true }
                .padding(.horizontal, Aura.margin)
                .padding(.bottom, 4)
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showNew) {
            ScheduleFormView(medication: nil)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
        .task {
            if notifications.authorization == .notDetermined {
                await notifications.requestAuthorization()
            }
        }
    }
}

struct AuraTabBar: View {
    @Binding var selection: AppTab
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            item(.hoy, "Hoy", "sun.max")
            item(.botiquin, "Botiquín", "cross.case")
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Aura.primary))
                    .shadow(color: Aura.primary.opacity(0.25), radius: 10, y: 6)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Nuevo recordatorio")
            .frame(maxWidth: .infinity)
            item(.progreso, "Progreso", "heart.text.square")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Aura.surfaceLowest)
        )
        .floatingShadow()
    }

    private func item(_ tab: AppTab, _ title: String, _ symbol: String) -> some View {
        let active = selection == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selection = tab }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: active ? .semibold : .regular))
                Text(title)
                    .font(.sans(12, active ? .semibold : .medium))
            }
            .foregroundStyle(active ? Aura.onSurface : Aura.onSurfaceVariant)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
