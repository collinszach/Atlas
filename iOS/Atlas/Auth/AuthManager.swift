import Foundation
import ClerkKit

@MainActor
@Observable
final class AuthManager {
    var isSignedIn: Bool = false
    var isLoading: Bool = true
    var error: String? = nil

    private(set) var api: APIClient = APIClient()

    init() {
        // Always hand the API client a fresh Clerk token; session tokens expire ~60s,
        // and Clerk.getToken() returns a cached one or transparently refreshes.
        api.tokenProvider = {
            if let token = try? await Clerk.shared.session?.getToken() {
                return token
            }
            return nil
        }
    }

    /// Called at app launch to restore session from Keychain / Clerk.
    func checkSession() async {
        defer { isLoading = false }
        // Prefer a live Clerk session; fall back to a stored token.
        if Clerk.shared.session != nil {
            isSignedIn = true
        } else {
            isSignedIn = api.token != nil
        }
    }

    /// Sign in via Clerk using email + password.
    func signIn(email: String, password: String) async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let signIn = try await Clerk.shared.auth.signInWithPassword(
                identifier: email,
                password: password
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

    /// Sign in (or auto-register) with Apple — native, no manual account creation.
    /// Clerk provisions a new user automatically on first use.
    func signInWithApple() async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await Clerk.shared.auth.signInWithApple()
            guard let token = try await Clerk.shared.session?.getToken() else {
                error = "Apple sign-in incomplete — please try again."
                return
            }
            api.persistToken(token)
            isSignedIn = true
        } catch is CancellationError {
            // user dismissed the Apple sheet — stay quiet
        } catch {
            let ns = error as NSError
            // ASAuthorizationError.canceled (code 1001) — don't surface as an error
            if ns.domain == "com.apple.AuthenticationServices.AuthorizationError" && ns.code == 1001 {
                return
            }
            self.error = error.localizedDescription
        }
    }

    /// Sign in (or auto-register) with Google via Clerk's OAuth web flow.
    func signInWithGoogle() async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await Clerk.shared.auth.signInWithOAuth(provider: .google)
            guard let token = try await Clerk.shared.session?.getToken() else {
                error = "Google sign-in incomplete — please try again."
                return
            }
            api.persistToken(token)
            isSignedIn = true
        } catch is CancellationError {
            // user dismissed the web sheet — stay quiet
        } catch {
            let ns = error as NSError
            // ASWebAuthenticationSessionError.canceledLogin (code 1) — don't surface
            if ns.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && ns.code == 1 {
                return
            }
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
            try? await Clerk.shared.auth.signOut()
        }
    }
}
