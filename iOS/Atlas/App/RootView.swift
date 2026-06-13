import SwiftUI

struct RootView: View {
    @State private var authManager = AuthManager()
    @Environment(AppState.self) private var appState

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
            appState.api = authManager.api
        }
    }
}

struct MainTabView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            MapView()
                .tabItem {
                    Label("Map", systemImage: "globe")
                }
                .tag(AppTab.map)

            TripListView()
                .tabItem {
                    Label("Trips", systemImage: "mappin.circle")
                }
                .tag(AppTab.trips)

            SkyView()
                .tabItem {
                    Label("Sky", systemImage: "airplane")
                }
                .tag(AppTab.sky)

            PlanView()
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }
                .tag(AppTab.plan)

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(AppTab.stats)
        }
        .tint(.atlasAccent)
        .background(Color.atlasBackground)
    }
}
