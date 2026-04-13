import SwiftUI
import ClerkSDK

struct RootView: View {
    @State private var authManager = AuthManager()

    var body: some View {
        Group {
            if authManager.isLoading {
                LoadingView()
            } else if authManager.isSignedIn {
                MainTabView()
                    .environment(authManager)
            } else {
                SignInView()
                    .environment(authManager)
            }
        }
        .background(Color.atlasBackground)
        .task {
            await authManager.checkSession()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            MapView()
                .tabItem {
                    Label("Map", systemImage: "globe")
                }

            TripListView()
                .tabItem {
                    Label("Trips", systemImage: "mappin.circle")
                }

            PlanView()
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
        }
        .tint(.atlasAccent)
        .background(Color.atlasBackground)
    }
}
