import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: GateModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var markerSize = 30

    var body: some View {
        NavigationStack {
            List {
                calculation
                Section {
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
                } header: {
                    informationHeading("Your window")
                } footer: {
                    Text("Applies to new calculations. Existing windows keep their end time. Time keeps passing when you switch apps or lock your phone.")
                        .font(.footnote).lineSpacing(3)
                }
                Section("Permissions") {
                    Label(model.authorized ? "Screen Time connected" : "Screen Time access needed",
                          systemImage: model.authorized ? "checkmark.shield" : "exclamationmark.shield")
                    if !model.authorized {
                        Button("Allow Screen Time access") { Task { await model.authorize() } }
                    }
                    if model.usesNotificationHandoff, model.notificationAuthorization != nil {
                        if !model.canManageNotifications {
                            Label("Challenge notifications allowed", systemImage: "bell.badge")
                        } else {
                            Button(model.needsNotificationPermission ? "Allow challenge notifications" : "Notification settings") {
                                Task { await model.allowNotifications() }
                            }
                            .disabled(model.isUpdatingNotifications)
                            .accessibilityIdentifier("manage-notifications")
                        }
                    }
                    Button("Open iPhone Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                walkthrough
                privacy
            }
            .scrollContentBackground(.hidden)
            .background(GateTheme.paper)
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Gate needs attention", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
        }
        .tint(GateTheme.blue)
    }

    private var calculation: some View {
        Section {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Example")
                        .font(.subheadline).foregroundStyle(GateTheme.muted)
                    Text("\(model.calculationSettings.example.expression) = ?")
                        .font(.system(.largeTitle, design: .rounded, weight: .medium))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                        .foregroundStyle(GateTheme.ink)
                        .accessibilityLabel("Example: \(model.calculationSettings.example.spokenExpression)")
                        .accessibilityIdentifier("calculation-example")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Operation").font(.subheadline.weight(.medium))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? 1 : 4), spacing: 8) {
                        ForEach(CalculationOperation.allCases) { operation in
                            operationButton(operation)
                        }
                    }
                }

                VStack(spacing: 16) {
                    digitPicker("One number", keyPath: \.firstDigits, identifier: "first-number-digits")
                    digitPicker("Other number", keyPath: \.secondDigits, identifier: "second-number-digits")
                }

                Text(calculationNote)
                    .font(.footnote).foregroundStyle(GateTheme.muted)
                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
        } header: {
            informationHeading("Your calculation")
        } footer: {
            Text(model.isDemo ? "Preview only. These choices reset when you relaunch the preview." : "Saved on your iPhone. Applies to new calculations, including practice.")
                .font(.footnote).lineSpacing(3)
        }
    }

    private var calculationNote: String {
        switch model.calculationSettings.operation {
        case .addition, .multiplication:
            return "New numbers every time. One correct answer opens a window."
        case .subtraction:
            return "Larger number first, so answers are never negative."
        case .division:
            return "Larger number first. Answers are always whole numbers, with no remainders."
        }
    }

    private func operationButton(_ operation: CalculationOperation) -> some View {
        let selected = model.calculationSettings.operation == operation
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(spacing: 16))
            : AnyLayout(VStackLayout(spacing: 5))
        return Button {
            var preferences = model.calculationSettings
            preferences.operation = operation
            model.setCalculationSettings(preferences)
        } label: {
            layout {
                Text(operation.symbol).font(.system(.title2, design: .rounded, weight: .medium))
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? 64 : nil)
                Text(operation.title).font(.system(.caption, design: .rounded, weight: .semibold))
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .foregroundStyle(selected ? GateTheme.paper : GateTheme.ink)
            .background(selected ? GateTheme.blue : GateTheme.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(operation.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("operation-\(operation.rawValue)")
    }

    private func digitPicker(_ title: String, keyPath: WritableKeyPath<CalculationSettings, CalculationDigits>, identifier: String) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 16))
        let picker = Picker(title, selection: Binding(
            get: { model.calculationSettings[keyPath: keyPath] },
            set: { value in
                var preferences = model.calculationSettings
                preferences[keyPath: keyPath] = value
                model.setCalculationSettings(preferences)
            }
        )) {
            ForEach(CalculationDigits.allCases) { digits in
                Text(digits.title).tag(digits)
            }
        }
        return layout {
            Text(title).font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
            if dynamicTypeSize.isAccessibilitySize {
                // Native segmented controls keep tiny labels at accessibility sizes.
                picker.pickerStyle(.menu).labelsHidden().font(.body)
                    .accessibilityIdentifier(identifier)
            } else {
                picker.pickerStyle(.segmented).frame(maxWidth: 180)
                    .accessibilityIdentifier(identifier)
            }
        }
    }

    private var walkthrough: some View {
        Section {
            VStack(alignment: .leading, spacing: 24) {
                step(1, title: "Open a protected app", detail: GateHandoff.opensAppDirectly
                     ? "Tap Solve to unlock on the blocking screen to open Gate."
                     : "Tap Prepare calculation, then open Gate from its notification or Home Screen.")
                step(2, title: "Work it out", detail: "Solve one calculation to earn \(model.unlockDuration.title) in that app.")
                step(3, title: "Use your window", detail: "Return using the app switcher or Home Screen. Gate blocks the app again when time is up.")
            }
            .padding(.vertical, 10)
            .listRowSeparator(.hidden)

            Button(action: practice) {
                Label("Try a practice calculation", systemImage: "pencil")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(GateTheme.blue)
                    .padding(.vertical, 6)
            }
        } header: {
            informationHeading("How it works")
        } footer: {
            Text("You can also tap Solve in Your apps. iOS controls the exact time the block returns.")
                .font(.footnote).lineSpacing(3)
        }
    }

    private var privacy: some View {
        Section {
            VStack(alignment: .leading, spacing: 24) {
                privacyPoint("iphone", title: "Saved on your iPhone", detail: "Your app choices and unlock windows stay on this device.")
                privacyPoint("eye.slash", title: "No account or tracking", detail: "No server, analytics, or AI. Calculations happen on your phone.")
                privacyPoint("hand.raised", title: "You're in control", detail: "Remove apps, change Screen Time access, or delete Gate whenever you want.")
            }
            .padding(.vertical, 10)
            .listRowSeparator(.hidden)
        } header: {
            informationHeading("Your data stays here")
        }
    }

    private func informationHeading(_ title: String) -> some View {
        Text(title)
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .foregroundStyle(GateTheme.ink)
            .textCase(nil)
            .padding(.top, 8).padding(.bottom, 6)
    }

    private func step(_ number: Int, title: String, detail: String) -> some View {
        explanationLayout {
            Text(String(number))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(GateTheme.blue)
                .frame(width: markerSize, height: markerSize)
                .background(GateTheme.blue.opacity(0.09), in: Circle())
            explanation(title: title, detail: detail)
        }
        .accessibilityElement(children: .combine)
    }

    private func privacyPoint(_ symbol: String, title: String, detail: String) -> some View {
        explanationLayout {
            Image(systemName: symbol)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(GateTheme.blue)
                .frame(width: markerSize, height: markerSize)
                .accessibilityHidden(true)
            explanation(title: title, detail: detail)
        }
        .accessibilityElement(children: .combine)
    }

    private var explanationLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            return AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        }
        return AnyLayout(HStackLayout(alignment: .top, spacing: 14))
    }

    private func explanation(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(GateTheme.ink)
            Text(detail)
                .font(.subheadline).foregroundStyle(GateTheme.muted)
                .lineSpacing(3)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func practice() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { model.beginChallenge(for: nil) }
    }
}
