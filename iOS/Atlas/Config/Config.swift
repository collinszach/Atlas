import Foundation

enum Config {
    /// Base URL of the Atlas backend. Points at the Mac's Tailscale IP so the
    /// phone reaches it from anywhere on the tailnet.
    static let apiBase = URL(string: "http://100.106.229.105:8000")!

    /// Clerk publishable key — copy from your Clerk dashboard.
    static let clerkPublishableKey = "pk_test_bGl2ZS13ZXJld29sZi01OC5jbGVyay5hY2NvdW50cy5kZXYk"
}
