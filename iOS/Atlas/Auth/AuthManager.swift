import Foundation
import ClerkSDK

@MainActor
@Observable
final class AuthManager {
    var isSignedIn: Bool = false
    var isLoading: Bool = true
    var error: String? = nil

    private(set) var api: APIClient = APIClient()

    /// Called at app launch to restore session from Keychain.
    func checkSession() async {
        defer { isLoading = false }
        // If we already have a stored token, treat as signed in.
        // The backend will reject it if expired.
        isSignedIn = api.token != nil
    }

    /// Sign in via Clerk using email + password.
    func signIn(email: String, password: String) async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        do {
            guard let client = Clerk.shared.client else {
                error = "Authentication service not ready. Please restart the app."
                return
            }
            let signIn = try await client.signIn.create(
                strategy: .password(identifier: email, password: password)
            )
            guard signIn.status == .complete,
                  let token = try await Clerk.shared.session?.getToken() else {
                error = "Sign-in incomplete — check credentials."
                return
            }
            api.persistToken(token)
            isSignedIn = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Refresh the JWT from Clerk before API calls if needed.
    func refreshToken() async throws {
        guard let token = try await Clerk.shared.session?.getToken() else {
            throw APIError.notAuthenticated
        }
        api.persistToken(token)
    }

    func signOut() {
        api.persistToken(nil)
        isSignedIn = false
        Task {
            try? await Clerk.shared.signOut()
        }
    }
}
