import SwiftUI
import UIKit

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

    init() {
        // Modern dark, translucent tab bar.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(Color.atlasBackground.opacity(0.65))
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            MapView()
                .tabItem { Label("Map", systemImage: "globe.americas.fill") }
                .tag(AppTab.map)

            SkyView()
                .tabItem { Label("Sky", systemImage: "dot.radiowaves.up.forward") }
                .tag(AppTab.sky)

            TripListView()
                .tabItem { Label("Flights", systemImage: "airplane.departure") }
                .tag(AppTab.trips)

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(AppTab.stats)
        }
        .tint(.atlasAccent)
        .background(Color.atlasBackground)
    }
}
