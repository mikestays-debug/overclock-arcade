import SwiftUI
import WebKit

@main
struct OverclockApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct RootView: View {
    @State private var isLoading = true
    @State private var gameState = ""
    @State private var web: WKWebView?

    /// Only show the control while a race is on — never over a menu.
    private var showsPause: Bool { gameState == "racing" || gameState == "paused" }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(red: 0.043, green: 0.059, blue: 0.118).ignoresSafeArea()

            GameView(isLoading: $isLoading, gameState: $gameState) { web = $0 }
                .ignoresSafeArea()

            // NOTE: the pause control is injected into the game's own #touch row
            // (see GameView.bridgeJS) so it sits between the turn and brake buttons
            // and matches their styling. No floating native button needed.

            if isLoading { SplashView().transition(.opacity) }
        }
        .animation(.easeOut(duration: 0.2), value: showsPause)
        .animation(.easeOut(duration: 0.2), value: gameState)
    }
}

struct SplashView: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Color(red: 0.043, green: 0.059, blue: 0.118).ignoresSafeArea()
            VStack(spacing: 18) {
                Image("AppLogo")
                    .resizable().interpolation(.high)
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .cyan.opacity(pulse ? 0.55 : 0.15), radius: pulse ? 26 : 10)
                Text("OVERCLOCK")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .tracking(5).foregroundStyle(.white)
                Text("RUNNING HOTTER THAN RATED")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(2.5).foregroundStyle(.cyan.opacity(0.75))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
