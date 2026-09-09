import SwiftUI

struct EmergencyUnlockView: View {
    @ObservedObject var model: GateModel
    let session: ChallengeSession
    let options: EmergencyUnlockOptions
    let onUnlocked: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selection = EmergencyUnlockDuration.fifteenMinutes
    @State private var feedback: String?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let now = timeline.date
                let choices = options.available(at: now)
                let expiry = try? options.expiry(for: selection, at: now)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Label("Passcode accepted", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(GateTheme.blue)
                        Text("Choose a window.")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                        if let app = session.app { AppIdentity(app: app).font(.headline) }
                        Text("Choose a window for this app. It will lock again automatically.")
                            .foregroundStyle(GateTheme.muted)
                        durationChoices(choices)
                        if choices.isEmpty {
                            Text(EmergencyUnlockError.expired.localizedDescription)
                                .foregroundStyle(GateTheme.muted)
                        } else if options.dayEndsAt.timeIntervalSince(now) < 900 {
                            Text("Less than 15 minutes remain today. This window will end tomorrow.")
                                .font(.footnote).foregroundStyle(GateTheme.muted)
                        } else {
                            Text("Today ends at midnight. Choose only the time you need.")
                                .font(.footnote).foregroundStyle(GateTheme.muted)
                        }
                        if let feedback {
                            Text(feedback).font(.subheadline).foregroundStyle(.red)
                                .accessibilityIdentifier("emergency-duration-feedback")
                        }
                    }
                    .padding(.horizontal, 28).padding(.vertical, 20)
                    .frame(maxWidth: 560).frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(alignment: .leading, spacing: 14) {
                        if let expiry {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("LOCKS AGAIN").font(.caption.weight(.semibold)).tracking(1.5)
                                    .foregroundStyle(GateTheme.muted)
                                Text(relockTime(expiry, now: now))
                                    .font(.system(.title2, design: .rounded, weight: .semibold))
                                    .accessibilityIdentifier("emergency-relock-time")
                            }
                        } else if !choices.isEmpty {
                            Text("Choose another window to continue.").font(.subheadline)
                        }
                        Button("Unlock app", action: confirm)
                            .buttonStyle(GateButtonStyle()).disabled(expiry == nil)
                            .accessibilityIdentifier("confirm-emergency-unlock")
                    }
                    .padding(.horizontal, 28).padding(.vertical, 16)
                    .frame(maxWidth: 560).frame(maxWidth: .infinity)
                    .background(GateTheme.paper)
                    .overlay(alignment: .top) { GateTheme.rule.frame(height: 1) }
                }
            }
            .background(GateTheme.paper).foregroundStyle(GateTheme.ink)
            .navigationTitle("Emergency bypass").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel-emergency-duration")
                }
            }
        }
        .tint(GateTheme.blue)
    }

    private func durationChoices(_ choices: [EmergencyUnlockDuration]) -> some View {
        // Six controls need no lazy layout; full measurement keeps large-text hit areas accurate.
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return VStack(spacing: 12) {
            ForEach(Array(stride(from: 0, to: choices.count, by: columns)), id: \.self) { start in
                HStack(spacing: 12) {
                    ForEach(Array(choices.dropFirst(start).prefix(columns))) { duration in
                        durationButton(duration)
                    }
                }
            }
        }
    }

    private func durationButton(_ duration: EmergencyUnlockDuration) -> some View {
        let selected = selection == duration
        return Button {
            selection = duration
            feedback = nil
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(duration == .today ? "Today" : duration.title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                    if duration == .today {
                        Text("Until midnight").font(.caption).foregroundStyle(GateTheme.muted)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? GateTheme.blue : GateTheme.rule)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(GateTheme.ink)
            .padding(16).frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(selected ? GateTheme.blue.opacity(0.08) : GateTheme.paper, in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(selected ? GateTheme.blue : GateTheme.rule, lineWidth: selected ? 2 : 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(duration == .today ? "Rest of today, until midnight" : duration.title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("emergency-duration-" + duration.rawValue)
    }

    private func relockTime(_ expiry: Date, now: Date) -> String {
        if selection == .today { return "Midnight tonight" }
        let time = expiry.formatted(date: .omitted, time: .shortened)
        return Calendar.current.isDate(expiry, inSameDayAs: now) ? time : "Tomorrow, \(time)"
    }

    private func confirm() {
        do {
            guard let expiry = try model.confirmEmergencyUnlock(selection, options: options, for: session) else {
                throw EmergencyUnlockError.expired
            }
            onUnlocked(expiry)
            dismiss()
        } catch { feedback = error.localizedDescription }
    }
}
