import SwiftUI

/// A floating pause control for touch devices.
///
/// The game already has `togglePause()` bound to **P** and **Escape** — but a phone
/// has no keyboard, so on touch that function is unreachable. This button simply
/// calls the function that already exists. No change to the game's code.
///
/// It only appears while a race is actually running, so it never sits on top of a menu.
struct PauseButton: View {
    let isPaused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(
                    Circle()
                        .fill(.black.opacity(0.42))
                        .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                )
                // A real shadow keeps it readable over a bright track.
                .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
        }
        .buttonStyle(PressableStyle())
        // Big enough to hit at speed without looking at it.
        .contentShape(Circle())
        .accessibilityLabel(isPaused ? "Resume" : "Pause")
    }
}

/// Presses in slightly so a tap feels acknowledged even before the game reacts.
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
