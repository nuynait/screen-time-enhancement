import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let ink = UIColor(red: 0.13, green: 0.25, blue: 0.42, alpha: 1)
        let blue = UIColor(red: 0.18, green: 0.35, blue: 0.76, alpha: 1)
        let subtitle = GateHandoff.opensAppDirectly
            ? "Solve a calculation to earn a window for \(application.localizedDisplayName ?? "this app"). Choose the unlock time in Gate."
            : "Prepare a calculation, then open Gate from its notification or Home Screen. Choose the unlock time in Gate."
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThinMaterialLight,
            backgroundColor: UIColor(red: 0.93, green: 0.96, blue: 1, alpha: 1),
            icon: UIImage(systemName: "multiply.circle.fill")?.withTintColor(blue, renderingMode: .alwaysOriginal),
            title: .init(text: "A moment before you scroll.", color: ink),
            subtitle: .init(text: subtitle, color: ink),
            primaryButtonLabel: .init(text: GateHandoff.opensAppDirectly ? "Solve to unlock" : "Prepare calculation", color: .white),
            primaryButtonBackgroundColor: blue,
            secondaryButtonLabel: .init(text: "Keep it closed", color: ink)
        )
    }
}
