import Foundation
import SwiftUI

final class SessionManager: ObservableObject {
    /// Tracks whether the user has confirmed/login during the current app session.
    /// This is intentionally in-memory only — it resets when the app process restarts.
    @Published var didConfirmLoginThisSession: Bool = false
}
