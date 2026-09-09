import SwiftUI

struct PasscodeView: View {
    enum Purpose: String, Identifiable {
        case set, change, remove, bypass
        var id: String { rawValue }
    }

    @ObservedObject var model: GateModel
    let purpose: Purpose
    var bypassTitle = "Bypass calculation"
    var bypassDetail = "Ask the person who keeps your passcode to enter it."
    var onBypass: ((String) throws -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var entry = ""
    @State private var currentPasscode: String?
    @State private var newPasscode: String?
    @State private var feedback: String?
    @FocusState private var focused: Bool

    private var confirming: Bool { newPasscode != nil }
    private var needsCurrent: Bool { (purpose == .change || purpose == .remove) && currentPasscode == nil }

    private var title: String {
        if purpose == .bypass { return "Emergency bypass" }
        if purpose == .remove { return "Turn off bypass" }
        return purpose == .change ? "Change passcode" : "Set up bypass"
    }

    private var heading: String {
        if confirming { return "One more time." }
        if needsCurrent || purpose == .bypass { return "Enter the passcode." }
        return "A key for someone\nyou trust."
    }

    private var detail: String {
        if confirming { return "Enter the same four digits again to confirm. Keep this code with your parent or trusted friend." }
        if purpose == .bypass { return bypassDetail }
        if needsCurrent {
            return purpose == .remove
                ? "Enter the current code to turn off emergency bypass. Calculations will still work."
                : "Enter the current code before choosing a new one."
        }
        return "Hand your iPhone to a parent or friend. Ask them to choose four digits and keep the code for when you need help."
    }

    private var buttonTitle: String {
        if purpose == .bypass { return bypassTitle }
        if purpose == .remove { return "Turn off bypass" }
        if confirming { return "Save passcode" }
        return "Continue"
    }

    private var visibleButtonTitle: String {
        // Keep the fixed action to one line at large text sizes, leaving room for the input above the keyboard.
        guard dynamicTypeSize.isAccessibilitySize else { return buttonTitle }
        if purpose == .remove { return "Turn off" }
        if confirming { return "Save" }
        return "Continue"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "key.fill")
                        .font(.system(.largeTitle, design: .rounded))
                        .foregroundStyle(GateTheme.blue)
                        .padding(18)
                        .background(GateTheme.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                        .accessibilityHidden(true)
                    Text(heading)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("passcode-heading")
                    Text(detail).font(.body).foregroundStyle(GateTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(confirming ? "Confirm four-digit passcode" : "Four-digit passcode")
                            .font(.subheadline.weight(.medium))
                        SecureField("4 digits", text: $entry)
                            .keyboardType(.numberPad)
                            .textContentType(.password)
                            .font(.system(.largeTitle, design: .rounded, weight: .medium))
                            .monospacedDigit().multilineTextAlignment(.center)
                            .padding(18)
                            .background(GateTheme.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(GateTheme.rule))
                            .focused($focused)
                            .accessibilityLabel(confirming ? "Confirm passcode" : "Passcode")
                            .accessibilityIdentifier("passcode-entry")
                            .onChange(of: entry) { _, value in
                                let digits = String(value.filter { $0.isASCII && $0.isNumber }.prefix(4))
                                if digits != value { entry = digits }
                                if !value.isEmpty { feedback = nil }
                            }
                    }
                    if let feedback {
                        Text(feedback).font(.subheadline).foregroundStyle(.red)
                            .accessibilityIdentifier("passcode-feedback")
                    }
                    if confirming {
                        Button("Choose a different code") {
                            newPasscode = nil
                            entry = ""
                            feedback = nil
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    if purpose == .set || purpose == .change {
                        Label(model.isDemo ? "Preview only. This code resets when you relaunch the preview."
                              : "Stored in this iPhone's Keychain. Gate never displays or sends your code.", systemImage: "lock.shield")
                            .font(.footnote).foregroundStyle(GateTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(28).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(GateTheme.paper).foregroundStyle(GateTheme.ink)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(visibleButtonTitle, action: submit)
                    .buttonStyle(GateButtonStyle())
                    .disabled(!EmergencyPasscode.isValid(entry))
                    .accessibilityLabel(buttonTitle)
                    .accessibilityIdentifier("submit-passcode")
                    .padding(.horizontal, 28).padding(.vertical, 16)
                    .background(GateTheme.paper)
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(purpose == .bypass ? "Back" : "Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel-passcode")
                }
            }
        }
        .tint(GateTheme.blue)
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            entry = ""
            currentPasscode = nil
            newPasscode = nil
            feedback = nil
            focused = false
        }
    }

    private func submit() {
        guard EmergencyPasscode.isValid(entry) else { return }
        do {
            if purpose == .bypass {
                guard let onBypass else { return }
                try onBypass(entry)
                dismiss()
            } else if purpose == .remove {
                try model.removeEmergencyPasscode(current: entry)
                dismiss()
            } else if needsCurrent {
                try model.verifyEmergencyPasscode(entry)
                currentPasscode = entry
                entry = ""
            } else if let newPasscode {
                try model.setEmergencyPasscode(newPasscode, confirmation: entry, current: currentPasscode)
                dismiss()
            } else {
                newPasscode = entry
                entry = ""
            }
        } catch {
            entry = ""
            feedback = error.localizedDescription
        }
    }
}
