import Foundation

enum Config {
    /// Base URL of the Atlas backend on the NUC.
    /// Change this to match your NUC's IP address or hostname.
    static let apiBase = URL(string: "http://192.168.1.100:8000")!

    /// Clerk publishable key — copy from your Clerk dashboard.
    static let clerkPublishableKey = "pk_live_REPLACE_ME"
}
