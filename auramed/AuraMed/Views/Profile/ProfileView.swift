import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var profile: Profile
    @EnvironmentObject private var notifications: NotificationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(NotificationManager.quietKey) private var quiet = false
    @State private var photo: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Aura.spaceLG) {
                HStack {
                    Text("PERFIL").font(.labelSM).tracking(1).foregroundStyle(Aura.onSurfaceVariant)
                    Spacer()
                    Button("Listo") { dismiss() }
                        .font(.sans(15, .semibold))
                        .foregroundStyle(Aura.primary)
                }

                VStack(spacing: 12) {
                    PhotosPicker(selection: $photo, matching: .images) {
                        AvatarView(size: 96)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Aura.primary))
                            }
                    }
                    if profile.avatar != nil {
                        Button("Usar foto predeterminada") { profile.setAvatar(nil) }
                            .font(.sans(12)).foregroundStyle(Aura.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tu nombre").font(.sans(16, .medium))
                    TextField("¿Cómo te llamamos?", text: $profile.name)
                        .font(.bodyLG)
                        .textContentType(.givenName)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Aura.surfaceHigh))
                }

                VStack(alignment: .leading, spacing: Aura.spaceMD) {
                    Text("Recordatorios").font(.serif(22))
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notificaciones").font(.sans(15, .medium))
                            Text(statusText).font(.bodySM).foregroundStyle(Aura.onSurfaceVariant)
                        }
                        Spacer()
                        if notifications.authorization == .notDetermined {
                            Button("Activar") { Task { await notifications.requestAuthorization() } }
                                .buttonStyle(SecondaryPillButtonStyle(fill: Aura.surfaceLowest))
                        } else if notifications.authorization == .denied {
                            Button("Ajustes") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                                .buttonStyle(SecondaryPillButtonStyle(fill: Aura.surfaceLowest))
                        } else {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Aura.primary)
                        }
                    }
                    Toggle(isOn: $quiet) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recordatorios silenciosos").font(.sans(15, .medium))
                            Text("Avisos sin sonido, solo una señal visual").font(.bodySM).foregroundStyle(Aura.onSurfaceVariant)
                        }
                    }
                    .tint(Aura.primary)
                    .onChange(of: quiet) { _, _ in notifications.reschedule() }
                }
                .auraCard(Aura.surfaceContainer, padding: Aura.spaceMD + 4)

                Label("Toda tu información se guarda localmente en este iPhone. Aura Med no usa cuentas ni servidores.", systemImage: "lock")
                    .font(.bodySM)
                    .foregroundStyle(Aura.onSurfaceVariant)
            }
            .padding(Aura.spaceLG)
        }
        .background(Aura.surface.ignoresSafeArea())
        .presentationCornerRadius(Aura.radiusLG)
        .onChange(of: photo) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    profile.setAvatar(img.preparingThumbnail(of: CGSize(width: 400, height: 400 * img.size.height / max(img.size.width, 1))) ?? img)
                }
            }
        }
    }

    private var statusText: String {
        switch notifications.authorization {
        case .authorized, .provisional, .ephemeral: "Activadas"
        case .denied: "Desactivadas en Ajustes de iOS"
        default: "Aún no activadas"
        }
    }
}
