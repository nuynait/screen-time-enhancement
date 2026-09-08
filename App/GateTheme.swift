import SwiftUI

enum GateTheme {
    static let paper = Color(light: UIColor(red: 0.95, green: 0.97, blue: 1, alpha: 1), dark: UIColor(red: 0.07, green: 0.10, blue: 0.16, alpha: 1))
    static let ink = Color(light: UIColor(red: 0.13, green: 0.22, blue: 0.36, alpha: 1), dark: UIColor(red: 0.87, green: 0.92, blue: 1, alpha: 1))
    static let blue = Color(light: UIColor(red: 0.18, green: 0.35, blue: 0.76, alpha: 1), dark: UIColor(red: 0.51, green: 0.67, blue: 1, alpha: 1))
    static let muted = Color(light: UIColor(red: 0.36, green: 0.43, blue: 0.55, alpha: 1), dark: UIColor(red: 0.63, green: 0.70, blue: 0.81, alpha: 1))
    static let rule = Color(light: UIColor(red: 0.80, green: 0.85, blue: 0.94, alpha: 1), dark: UIColor(red: 0.23, green: 0.30, blue: 0.41, alpha: 1))
}

private extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

struct GateButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(Color.white)
            .background(Color(red: 0.18, green: 0.35, blue: 0.76).opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.45), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct AppIdentity: View {
    let app: AppRow
    var body: some View {
        if let token = app.token {
            Label(token)
        } else {
            Label {
                Text(app.demoName ?? "Practice")
            } icon: {
                Image(systemName: app.demoName == "Bilibili" ? "play.rectangle.fill" : "text.bubble.fill")
                    .foregroundStyle(app.demoName == "Bilibili" ? .pink : .red)
            }
        }
    }
}
