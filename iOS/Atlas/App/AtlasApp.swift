import SwiftUI
import ClerkSDK

@main
struct AtlasApp: App {
    init() {
        Clerk.shared.configure(publishableKey: Config.clerkPublishableKey)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
