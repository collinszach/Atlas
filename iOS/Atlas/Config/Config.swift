import Foundation

enum Config {
    /// Base URL of the Atlas backend, which runs on the NUC (GS65) over Tailscale.
    static let apiBase = URL(string: "http://100.119.105.2:8000")!

    /// Clerk publishable key — copy from your Clerk dashboard.
    static let clerkPublishableKey = "pk_test_bGl2ZS13ZXJld29sZi01OC5jbGVyay5hY2NvdW50cy5kZXYk"
}
