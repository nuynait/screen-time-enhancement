import SwiftUI

struct ChallengeView: View {
    @ObservedObject var model: GateModel
    let session: ChallengeSession
    let onSettingsUnlocked: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var answer = ""
    @State private var feedback: String?
    @State private var expiresAt: Date?
    @FocusState private var answerFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let expiresAt { success(until: expiresAt) }
                    else { calculation }
                }
                .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(GateTheme.paper).foregroundStyle(GateTheme.ink)
            .navigationTitle(session.isSettingsGate ? "Open Settings" : (session.app == nil ? "Practice" : "Earn a window"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(expiresAt == nil ? "Cancel" : "Done") { dismiss() }
                }
            }
        }
        .tint(GateTheme.blue)
    }

    private var calculation: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let app = session.app { AppIdentity(app: app).font(.headline) }
            Text(session.isSettingsGate ? "Before you\nchange the rules." : "Take a moment.\nWork it out.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(session.isSettingsGate ? "Solve your current calculation to open Settings. Existing app windows keep their end times."
                 : (session.app == nil ? "A practice round. No apps will be unlocked." : "One correct answer opens this app for \(session.unlockDuration.title)."))
                .font(.body).foregroundStyle(GateTheme.muted)
            if session.wasRefreshed {
                Text("New calculation after leaving Gate.")
                    .font(.footnote).foregroundStyle(GateTheme.muted)
                    .accessibilityIdentifier("challenge-refreshed")
            }
            VStack(spacing: 18) {
                Text(session.problem.expression)
                    .font(.system(size: 62, weight: .medium, design: .rounded))
                    .minimumScaleFactor(0.5).lineLimit(1).monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(session.problem.spokenExpression)
                    .accessibilityIdentifier("problem")
                Rectangle().fill(GateTheme.rule).frame(height: 2)
                TextField("Your answer", text: $answer)
                    .keyboardType(.numberPad)
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .focused($answerFocused)
                    .padding(.vertical, 8)
                    .accessibilityLabel("Your answer").accessibilityIdentifier("answer")
                    .onChange(of: answer) { _, value in
                        let filtered = String(value.filter { $0.isASCII && $0.isNumber }.prefix(8))
                        if value != filtered { answer = filtered }
                        feedback = nil
                    }
            }
            .padding(.vertical, 22)
            if let feedback {
                Text(feedback).font(.subheadline).foregroundStyle(.red)
                    .accessibilityIdentifier("answer-feedback")
            }
            Button(session.isSettingsGate ? "Open Settings" : (session.app == nil ? "Check answer" : "Unlock for \(session.unlockDuration.title)"), action: submit)
                .buttonStyle(GateButtonStyle()).disabled(answer.isEmpty)
                .accessibilityIdentifier("submit-answer")
            Button(session.isSettingsGate ? "Keep my settings" : "Keep it closed") { dismiss() }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 8)
        }
    }

    private func success(until date: Date) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60)).foregroundStyle(GateTheme.blue)
                .padding(.top, 20).accessibilityHidden(true)
            Text(session.app == nil ? "You worked it out." : "Your window is open.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .accessibilityIdentifier("unlock-success")
            Text("\(session.problem.expression) = \(session.problem.answer)")
                .font(.system(.title2, design: .rounded, weight: .medium))
            if let app = session.app {
                AppIdentity(app: app).font(.headline)
                Text("Return to the app. It will lock again at \(date.formatted(date: .omitted, time: .shortened)).")
                    .font(.body).foregroundStyle(GateTheme.muted)
                Text(timerInterval: Date()...max(Date(), date), countsDown: true)
                    .font(.system(size: 48, weight: .medium, design: .rounded)).monospacedDigit()
                    .foregroundStyle(GateTheme.blue)
                    .accessibilityIdentifier("unlock-countdown")
                if model.isDemo {
                    Text("Preview only. No access settings have changed.")
                        .font(.footnote).foregroundStyle(GateTheme.muted)
                }
            }
            Button("Done") { dismiss() }.buttonStyle(GateButtonStyle()).accessibilityIdentifier("finish-challenge")
        }
    }

    private func submit() {
        guard session.problem.accepts(answer) else {
            feedback = "Not quite. Take another look and try again."
            return
        }
        do {
            guard let expiry = try model.submit(answer, for: session) else {
                feedback = "This calculation has expired. Close it and start again."
                return
            }
            answerFocused = false
            if session.isSettingsGate {
                onSettingsUnlocked()
                dismiss()
                return
            }
            expiresAt = expiry
        } catch {
            feedback = "Couldn't unlock the app. \(error.localizedDescription)"
        }
    }
}
