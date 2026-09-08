# Roadmap

## First version

- [x] Standalone generated Xcode project with app and three extensions.
- [x] Individual authorization and explicit application selection.
- [x] Random two-digit multiplication and answer validation.
- [x] Per-app, 15-minute grants and early locking.
- [x] Device Activity expiry registered before unshielding.
- [x] Cross-process persistence and current-state reconciliation.
- [x] Pending-app routing from a shield action.
- [x] iOS 26.5 direct handoff source with SDK/runtime gates.
- [x] Notification/manual handoff for older SDKs and OS versions.
- [x] SwiftUI app, practice flow, countdowns, settings, and source-drawn icon.
- [x] Pass 11 core tests and both simulator interaction tests; inspect screenshots.
- [x] Support per-developer signing and verify a signed development build of all four targets.
- [ ] Validate direct handoff with an iOS 26.5+ SDK and a compatible phone.
- [ ] Complete physical-device acceptance, especially expiry while Gate is closed.

## Possible follow-ups

- Challenge count and difficulty options, if requested.
- Shortcuts integration for an automatic app-open redirect, if requested.
- Optional known-app launch shortcuts after solving, without guessing opaque token identities.
- TestFlight distribution after Family Controls entitlement approval for every target.

Whole-category blocking, website blocking, usage tracking, AI, cloud sync, and parental management are outside this first version.

## Configurable unlock time

- [x] Settings menu with 1, 3, 5, 10, 15, 30, and 60 minutes; default to 15.
- [x] Persist the preference without changing existing grants or losing old saved state.
- [x] Use the duration offered by each calculation for its grant and countdown.
- [x] Test duration changes, persistence, legacy state, and schedule dates; inspect the Settings screenshot and build all four targets for simulator and signed iPhone development.
- [ ] Verify short-window background expiry on a physical iPhone.

## Public repository

- [x] Generic public bundle defaults and ignored local signing overrides.
- [x] Automatically choose a compatible installed iPhone simulator.
- [x] README screenshot walkthrough, setup instructions, contributor guide, and MIT license.
- [x] Ignore generated projects, build outputs, credentials, and private development notes.
- [x] Validate a clean checkout with generic identifiers and no local signing file.
- [x] Prepare the public GitHub repository with an audited source and documentation set.

## Notification permissions

- [x] Ask once after Screen Time setup when the notification handoff is needed.
- [x] Hide home guidance once notifications are authorized.
- [x] Open notification settings from the permission button after denial.
- [x] Refresh the OS permission on returning to Gate.
- [x] Verify fresh Allow/Don't Allow prompts, conditional guidance, and Settings handoff in the simulator; inspect screenshots and build the signed iPhone app.
- [ ] Verify toggling notification permission in Settings and returning on a physical iPhone.

## Settings presentation

- [x] Remove the decorative top-left multiplication icon from the home screen.
- [x] Present How it works as three numbered steps with a practice action.
- [x] Present privacy details as short titled points with descriptive icons.
- [x] Stack the explanation rows vertically at accessibility text sizes.
- [x] Check the existing UI flows and inspect light, dark, and large-text captures.
