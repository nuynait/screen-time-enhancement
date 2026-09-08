import FamilyControls
import SwiftUI

struct HomeView: View {
    @ObservedObject var model: GateModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingPicker = false
    @State private var showingSettings = false
    @State private var openSettingsAfterChallenge = false
    @State private var pickerSelection = FamilyActivitySelection()
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    if model.isDemo {
                        Label("Preview · no apps are blocked", systemImage: "eye")
                            .font(.footnote).foregroundStyle(GateTheme.muted)
                    }
                    introduction
                    if !model.authorized { authorization }
                    if model.apps.isEmpty { emptySelection }
                    else { appList }
                    if model.authorized && model.needsNotificationPermission {
                        handoffHelp
                    }
                    Text("A little effort. A deliberate choice.")
                        .font(.subheadline).foregroundStyle(GateTheme.muted)
                        .frame(maxWidth: .infinity).padding(.top, 8)
                }
                .padding(.horizontal, 26).padding(.top, 20).padding(.bottom, 36)
            }
            .background(GateTheme.paper)
            .foregroundStyle(GateTheme.ink)
            .navigationTitle("Gate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "slider.horizontal.3") { model.beginSettingsChallenge() }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("settings")
                }
            }
            .sheet(isPresented: $showingPicker) {
                NavigationStack {
                    FamilyActivityPicker(selection: $pickerSelection)
                        .navigationTitle("Choose apps")
                        .navigationBarTitleDisplayMode(.inline)
                        .safeAreaInset(edge: .bottom) {
                            Text("Select individual apps inside a category. Up to 12 apps.")
                                .font(.footnote).padding().frame(maxWidth: .infinity)
                                .background(.regularMaterial)
                        }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingPicker = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    if model.saveSelection(pickerSelection) { showingPicker = false }
                                }
                            }
                        }
                        .alert("Couldn't save apps", isPresented: errorBinding) {
                            Button("OK") { model.errorMessage = nil }
                        } message: { Text(model.errorMessage ?? "") }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(model: model).allowsHitTesting(showingSettings)
            }
            .sheet(item: $model.challenge, onDismiss: {
                // Present only after the successful gate has finished dismissing its sheet.
                if openSettingsAfterChallenge {
                    openSettingsAfterChallenge = false
                    showingSettings = true
                }
            }) { session in
                ChallengeView(model: model, session: session) { openSettingsAfterChallenge = true }
                    .id(session.id)
            }
            .alert("Gate needs attention", isPresented: Binding(
                get: { model.errorMessage != nil && !showingPicker && !showingSettings },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
            .onReceive(refreshTimer) { _ in
                // Refresh expired labels and reconcile shields while Gate is foregrounded.
                // The extension owns expiry when another app is on screen.
                model.refresh()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .background else { return }
                // Settings access lasts for this foreground visit, not a reusable grace period.
                openSettingsAfterChallenge = false
                showingSettings = false
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A pause before\nthe scroll.")
                .font(.system(size: 39, weight: .bold, design: .rounded))
                .tracking(-1.2).fixedSize(horizontal: false, vertical: true)
            Text("Solve one calculation to earn \(model.unlockDuration.title) in an app.")
                .font(.body).foregroundStyle(GateTheme.muted).lineSpacing(4)
            HStack(spacing: 12) {
                Image(systemName: model.calculationSettings.operation.systemImage).font(.title3.weight(.semibold))
                    .accessibilityHidden(true)
                Text(model.calculationSettings.summary)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                Spacer()
                Image(systemName: "lock").font(.subheadline)
            }
            .foregroundStyle(GateTheme.blue)
            .padding(18).background(GateTheme.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var authorization: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("First, allow Screen Time access.").font(.headline)
            Text("Gate uses it to block the apps you choose and let you back in after a calculation.")
                .font(.subheadline).foregroundStyle(GateTheme.muted)
            Button { Task { await model.authorize() } } label: {
                HStack {
                    if model.isAuthorizing { ProgressView().tint(.white) }
                    Text(model.isAuthorizing ? "Connecting…" : "Allow Screen Time access")
                }
            }
            .buttonStyle(GateButtonStyle()).disabled(model.isAuthorizing)
            .accessibilityIdentifier("authorize")
        }
    }

    private var emptySelection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("What pulls you in?").font(.system(.title2, design: .rounded, weight: .semibold))
            Text("Choose apps like Rednote or Bilibili. They'll stay closed until you earn a window.")
                .font(.subheadline).foregroundStyle(GateTheme.muted)
            if model.authorized {
                Button("Choose apps", action: openPicker).buttonStyle(GateButtonStyle())
            }
            Button("Try a practice calculation") { model.beginChallenge(for: nil) }
                .font(.subheadline.weight(.semibold)).padding(.vertical, 8)
                .accessibilityIdentifier("practice")
        }
    }

    private var appList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Your apps").font(.system(.title2, design: .rounded, weight: .semibold))
                Spacer()
                if !model.isDemo {
                    Button("Edit", action: openPicker).font(.subheadline.weight(.semibold)).disabled(!model.authorized)
                }
            }.padding(.bottom, 12)
            ForEach(model.apps) { app in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        AppIdentity(app: app).font(.headline)
                        Spacer()
                        if let grant = model.grant(for: app.id), model.authorized {
                            Text(timerInterval: grant.issuedAt...grant.expiresAt, countsDown: true)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .monospacedDigit().foregroundStyle(GateTheme.blue)
                                .frame(width: 62).accessibilityLabel("Time remaining")
                                .accessibilityValue(Text(timerInterval: grant.issuedAt...grant.expiresAt, countsDown: true))
                                .accessibilityIdentifier("countdown-\(app.id.uuidString)")
                        } else {
                            Button("Solve") { model.beginChallenge(for: app) }
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 18).padding(.vertical, 12)
                                .background(GateTheme.blue.opacity(0.09), in: Capsule())
                                .disabled(!model.authorized)
                                .accessibilityIdentifier("solve-\(app.id.uuidString)")
                        }
                    }
                    HStack {
                        Label(status(for: app), systemImage: model.grant(for: app.id) == nil ? "lock.fill" : "lock.open")
                            .font(.caption).foregroundStyle(GateTheme.muted)
                        Spacer()
                        if model.grant(for: app.id) != nil, model.authorized {
                            Button("Lock now") { model.lock(app) }
                                .font(.caption.weight(.semibold)).padding(.vertical, 8)
                                .accessibilityIdentifier("lock-\(app.id.uuidString)")
                        }
                    }
                }
                .padding(.vertical, 18)
                Rectangle().fill(GateTheme.rule).frame(height: 1)
            }
        }
    }

    private var handoffHelp: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Opening a calculation", systemImage: "bell.badge").font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("notification-guidance")
            Text(model.notificationAuthorization == .denied
                 ? "Notifications are off. Enable them in iPhone Settings to open calculations from a notification. You can also open Gate from your Home Screen."
                 : "Allow notifications so you can tap Prepare calculation on a blocked app, then tap Gate's notification to solve it. You can also open Gate from your Home Screen.")
                .font(.subheadline).foregroundStyle(GateTheme.muted)
            Button("Allow challenge notifications") { Task { await model.allowNotifications() } }
                .font(.subheadline.weight(.semibold)).padding(.vertical, 6)
                .disabled(model.isUpdatingNotifications)
                .accessibilityIdentifier("allow-notifications")
        }
    }

    private func status(for app: AppRow) -> String {
        if !model.authorized { return "Screen Time access needed" }
        return model.grant(for: app.id) == nil ? "Calculation required" : "Window open"
    }

    private func openPicker() {
        pickerSelection = model.selection
        showingPicker = true
    }
}
