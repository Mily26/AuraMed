import SwiftUI
import UIKit

/// Local profile: name and photo, stored on the device (UserDefaults + Documents).
@MainActor
final class Profile: ObservableObject {
    static let shared = Profile()

    @Published var name: String = UserDefaults.standard.string(forKey: "userName") ?? "" {
        didSet { UserDefaults.standard.set(name, forKey: "userName") }
    }
    @Published private(set) var avatar: UIImage?

    private var avatarURL: URL {
        URL.documentsDirectory.appending(path: "avatar.jpg")
    }

    init() {
        if let data = try? Data(contentsOf: avatarURL) {
            avatar = UIImage(data: data)
        }
    }

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? ""
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let base: String
        switch hour {
        case 5..<13: base = "Buenos días"
        case 13..<20: base = "Buenas tardes"
        default: base = "Buenas noches"
        }
        return firstName.isEmpty ? base : "\(base), \(firstName)"
    }

    func setAvatar(_ image: UIImage?) {
        objectWillChange.send()
        if let image, let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: avatarURL, options: .atomic)
            avatar = image
        } else {
            try? FileManager.default.removeItem(at: avatarURL)
            avatar = nil
        }
    }
}
