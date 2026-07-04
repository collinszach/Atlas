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
        // Give Clerk's fire-and-forget configure() load a moment to settle.
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let hasSession = Clerk.shared.session != nil
        Self.logDiagnostic(
            "launch",
            NSError(domain: "diagnostic", code: 0, userInfo: ["hasSession": hasSession]),
            clerkLoaded: Clerk.shared.isLoaded
        )
        // Require a LIVE Clerk session. A stale persisted token (no session) only
        // produces 401s on every request and traps the user "signed in" — drop it.
        if hasSession {
            isSignedIn = true
        } else {
            api.persistToken(nil)
            isSignedIn = false
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
            Self.logDiagnostic("signIn(email)", error, clerkLoaded: Clerk.shared.isLoaded)
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
            Self.logDiagnostic("signInWithApple", error, clerkLoaded: Clerk.shared.isLoaded)
            self.error = error.localizedDescription
        }
    }

    /// Writes full error detail to Documents/auth_error.log so it can be pulled off the
    /// device for diagnosis (the on-screen banner truncates and hides the underlying cause).
    static func logDiagnostic(_ where_: String, _ error: Error, clerkLoaded: Bool) {
        let ns = error as NSError
        let text = """
        [\(Date())] \(where_)
        clerkLoaded=\(clerkLoaded)
        localizedDescription=\(error.localizedDescription)
        domain=\(ns.domain) code=\(ns.code)
        userInfo=\(ns.userInfo)
        reflecting=\(String(reflecting: error))

        """
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = dir.appendingPathComponent("auth_error.log")
            if let data = text.data(using: .utf8) {
                if let h = try? FileHandle(forWritingTo: url) {
                    h.seekToEndOfFile(); h.write(data); try? h.close()
                } else {
                    try? data.write(to: url)
                }
            }
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
            Self.logDiagnostic("signInWithGoogle", error, clerkLoaded: Clerk.shared.isLoaded)
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
