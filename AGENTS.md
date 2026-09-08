# Agent instructions — Screen Time Enhancement

This is the standalone iPhone project **Gate**. It has no dependencies on other local repositories.

Read `README.md`, `docs/design-log.md`, and `docs/device-testing.md` before making changes. Keep decisions in the repo: append meaningful decisions and actual verification to `docs/design-log.md`, update the README for behavior changes, and maintain `docs/roadmap.md`.

`project.yml` generates `ScreenTimeEnhancement.xcodeproj` and the Info.plists. Edit the YAML and run `./scripts/generate.sh`; don't hand-edit the generated project. `Config/Local.xcconfig` is ignored and owns personal signing settings. Do not choose a different Apple Developer team without the user's authorization.

Keep public defaults generic. Personal team IDs, bundle identifiers, device IDs, local paths, and machine-specific notes belong in ignored `Config/Local.xcconfig` or `.local/`, not in tracked files. Preserve existing local signing overrides when changing public configuration. Screenshots must contain sample data and clearly distinguish preview behavior from verified device enforcement.

The app and all three extensions share `Core/` and `Shared/`. Persist through `LockedJSONStore`; UserDefaults or a process-local queue cannot serialize writes from independent extensions. Corrupt storage must report an error, never silently reset the app selection.

Keep these properties:

- Register a Device Activity expiry before removing a shield. Scheduling failure must grant no access.
- A grant belongs to exactly one app and preserves the duration offered when its calculation opened. The default is 15 minutes; changing preferences never rewrites active grants.
- Each grant gets its own monitor name; a late callback must preserve newer active grants.
- Never call `startMonitoring` or `stopMonitoring` while holding the shared file lock; the OS may call the extension synchronously.
- Use explicit application tokens only. Category and website selection is unsupported and must be rejected visibly.
- Direct handoff requires both a compatible SDK and iOS 26.5+. Don't guess an enum raw value or use private APIs. `generate.sh` detects the SDK symbol.
- Demo behavior is Debug-only, explicit, labeled, and never writes real shield settings.
- Screen Time requires physical-device verification. A build or preview does not prove enforcement or expiry.

Run `./scripts/test.sh` for policy/storage changes, build all targets with `./scripts/build.sh`, and use `./scripts/test-ui.sh <sim-udid>` for interaction changes. Inspect simulator screenshots for visual changes. Follow the device checklist when a provisioned phone and compatible Xcode are available; document what's unverified if they aren't.

If creating commits, use Conventional Commits.
