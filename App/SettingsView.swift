import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: GateModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Your gate") {
                    LabeledContent("Challenge", value: "Two digits × two digits")
                    LabeledContent("Correct answers needed", value: "1")
                    Picker("Unlock time", selection: Binding(
                        get: { model.unlockDuration },
                        set: { model.setUnlockDuration($0) }
                    )) {
                        ForEach(UnlockDuration.allCases) { duration in
                            Text(duration.title).tag(duration)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("unlock-duration-picker")
                    Text("Applies to new calculations. Existing windows keep their end time.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Each window applies to one app. Time keeps passing when you switch apps or lock your phone.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Permissions") {
                    Label(model.authorized ? "Screen Time connected" : "Screen Time access needed",
                          systemImage: model.authorized ? "checkmark.shield" : "exclamationmark.shield")
                    if !model.authorized {
                        Button("Allow Screen Time access") { Task { await model.authorize() } }
                    }
                    if !GateHandoff.opensAppDirectly {
                        Button("Allow challenge notifications") { Task { await model.allowNotifications() } }
                    }
                    Button("Open iPhone Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                Section("How it works") {
                    Text(GateHandoff.opensAppDirectly
                         ? "Open a protected app and tap Solve to unlock. Gate opens with a calculation for that app."
                         : "Open a protected app and tap Prepare calculation. Tap Gate's notification or open Gate from your Home Screen to solve it.")
                    Text("After a correct answer, return to the app using the app switcher or Home Screen. Gate restores its block when the window ends; iOS controls the timing of that update.")
                    Text("You can also start a calculation from Your apps in Gate.")
                }
                Section("Your data stays here") {
                    Text("Gate has no account, server, analytics, or AI. Calculations and answers stay on your phone. Apple supplies private tokens for the apps you select.")
                    Text("You're in control. You can remove apps from Gate, revoke Screen Time access, or delete Gate in Settings.")
                }
                Section {
                    Button("Try a practice calculation") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { model.beginChallenge(for: nil) }
                    }
                }
            }
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Gate needs attention", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
        }
    }
}
