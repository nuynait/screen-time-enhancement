# Agent instructions — Screen Time Enhancement

This is the standalone iPhone project **Gate**. It has no dependencies on other local repositories.

Read `README.md`, `docs/design-log.md`, and `docs/device-testing.md` before making changes. Keep decisions in the repo: append meaningful decisions and actual verification to `docs/design-log.md`, update the README for behavior changes, and maintain `docs/roadmap.md`.

`project.yml` generates `ScreenTimeEnhancement.xcodeproj` and the Info.plists. Edit the YAML and run `./scripts/generate.sh`; don't hand-edit the generated project. `Config/Local.xcconfig` is ignored and owns personal signing settings. Do not choose a different Apple Developer team without the user's authorization.

Keep public defaults generic. Personal team IDs, bundle identifiers, device IDs, local paths, and machine-specific notes belong in ignored `Config/Local.xcconfig` or `.local/`, not in tracked files. Preserve existing local signing overrides when changing public configuration. Screenshots must contain sample data and clearly distinguish preview behavior from verified device enforcement.

The app and all three extensions share `Core/` and `Shared/`. Persist shared state through `LockedJSONStore`; UserDefaults or a process-local queue cannot serialize writes from independent extensions. Corrupt storage must report an error, never silently reset the app selection. The app-only emergency passcode belongs in the device-local Keychain, never shared JSON or UserDefaults. Preview passcodes stay in memory.

Keep these properties:

- Register a Device Activity expiry before removing a shield. Scheduling failure must grant no access.
- A grant belongs to exactly one app. Math preserves the duration offered when its calculation opened; emergency access uses the explicitly confirmed bypass window. The default is 15 minutes; changing preferences never rewrites active grants.
- Unfinished challenges become invalid on leaving the foreground. Returning must change both operands and the answer, reset input, and retain the offered operation/digit sizes/duration. Completed challenges and grants are preserved.
- Settings requires the current calculation or configured emergency passcode on every visit and after backgrounding. Passing this gate never creates or changes app grants.
- App emergency bypass requires the code, then a separate duration confirmation from 15 minutes through local midnight. Verification alone grants nothing. Authorization is bound to the current challenge and picker, cleared on cancellation/backgrounding, and cannot roll into another day. In the last 15 minutes of the day, only a full 15-minute window is offered. It uses the same grant path as a correct answer. Changing or removing an existing passcode requires that passcode; failed reads/writes must never silently reset it or grant access.
- Each grant gets its own monitor name; a late callback must preserve newer active grants.
- Never call `startMonitoring` or `stopMonitoring` while holding the shared file lock; the OS may call the extension synchronously.
- Use explicit application tokens only. Category and website selection is unsupported and must be rejected visibly.
- Direct handoff requires both a compatible SDK and iOS 26.5+. Don't guess an enum raw value or use private APIs. `generate.sh` detects the SDK symbol.
- Demo behavior is Debug-only, explicit, labeled, and never writes real shield settings.
- Screen Time requires physical-device verification. A build or preview does not prove enforcement or expiry.

Run `./scripts/test.sh` for policy/storage changes, build all targets with `./scripts/build.sh`, and use `./scripts/test-ui.sh <sim-udid>` for interaction changes. Inspect simulator screenshots for visual changes. Follow the device checklist when a provisioned phone and compatible Xcode are available; document what's unverified if they aren't.

The simulator test script uses ad-hoc signing without requiring a developer account. Keychain integration belongs in the app-hosted `AppTests/` target, not the UI runner, which has no app identity. Keep the test action's explicit `--demo` argument; ordinary Run must still launch the real app. Keychain fixtures use unique services and clean up afterward.

If creating commits, use Conventional Commits.
