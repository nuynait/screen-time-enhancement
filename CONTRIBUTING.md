# Contributing to Gate

Clone the repo, install XcodeGen, and run `./scripts/run-simulator.sh` to explore the app without configuring signing. Use your own ignored `Config/Local.xcconfig` for physical-device work.

## Make a change

- Edit `project.yml` and regenerate when changing project configuration. Do not commit the generated Xcode project, SDK detection file, or Info.plists.
- Keep signing identities, device IDs, provisioning files, and local paths out of source and documentation. `.local/` is available for private development notes.
- Add focused coverage for behavior that could change access or lose state. Use `./scripts/test.sh` for the core, `./scripts/build.sh` for all targets, and `./scripts/test-ui.sh` for interface flows.
- Inspect screenshots for UI changes. Use sample data and identify simulator previews; don't present them as evidence of real blocking.
- Append decisions and actual verification to `docs/design-log.md`. Update the README and roadmap when behavior or scope changes.
- Use Conventional Commits, such as `fix(gate): preserve newer unlock windows`.

## Preserve the gate's guarantees

1. Register the OS expiry **before** removing an app's shield. A failed registration grants no access.
2. Keep windows per app and expire them from persisted dates. Reopening Gate or changing the duration preference must not restart a timer. A calculation grants the duration it offered when opened; legacy state defaults to 15 minutes. Emergency app access separately confirms a 15-minute-to-midnight window after verifying the code. Never grant access at verification, reuse a canceled/backgrounded authorization, or move a captured midnight into a later day.
3. Preserve newer active windows when an old monitor callback arrives.
4. Serialize shared app/extension writes with the file lock; an actor or queue in one process cannot protect another process's writes.
5. Never call Device Activity monitoring methods while holding that lock. The OS can invoke extensions immediately.
6. Treat corrupt storage as an error, not permission to silently reset the selection.
7. Use public SDK APIs with both compile-time and runtime checks for direct shield handoff.
8. Keep the emergency credential in the device-only Keychain, separate from shared grant state. Both math and passcode completion must validate the active challenge and use the same unlock path. Recheck the current passcode before changing or removing it; previews must never read or write the real credential.

Screen Time integration changes need the [physical-device checklist](docs/device-testing.md). A successful simulator test or signed build proves neither blocking nor background expiry. Report your actual Xcode/iOS versions and the tests you performed in the pull request.
