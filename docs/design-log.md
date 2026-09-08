# Design log

Append new decisions at the bottom, including failures and what was actually verified.

## 2026-09-08 — First implementation

**Request.** Create a standalone iPhone app that makes opening distracting apps require a two-digit multiplication problem, then grants 15 minutes of access. The initial defaults are one correct answer and one app per window.

**Architecture.** Native SwiftUI app plus Shield Action, Shield Configuration, and Device Activity Monitor extensions. The app uses individual Family Controls authorization. Selected applications remain shielded except for active per-app grants. No backend or API keys are needed. Target iOS 17.0 for the existing SwiftUI API surface.

**SDK finding.** Xcode 26.3 (17C529)'s ManagedSettings Swift interface lacks `openParentalControlsApp`. Apple's current documentation marks that case as introduced in iOS 26.5. Runtime `#available` alone cannot compile a symbol missing from the SDK, even if the target phone is newer. The project generator detects the SDK symbol and sets a custom compilation condition. Both SDK and runtime gates protect the direct response. Older builds queue a local notification and close the protected app; their shield copy also explains manual opening of Gate. Upgrading Xcode and regenerating is necessary to build the direct handoff. Do not replace this with a guessed enum raw value.

**Device tooling.** Development encountered a phone whose developer disk image could not be mounted. Discovery of a device does not prove that Xcode can run code on it. Physical-device validation needs functioning device support and provisioned targets; simulator checks can proceed independently.

**Privacy and routing.** Store Apple's opaque `ApplicationToken`s. Maintain local UUIDs for stable rows and per-app grants. A shield action stores the token's UUID as a pending challenge, and Gate consumes it on activation. Pending requests expire after ten minutes. The application picker is explicit-app-only: whole categories and domains are rejected instead of appearing protected when they aren't. Do not infer readable app names or invent URL schemes. After solving, the user returns with the app switcher/Home Screen.

**Expiry.** A correct answer registers a unique Device Activity schedule before persisting an unlock and removing its shield. Scheduling errors leave the shield on. The grant lasts exactly 900 seconds from issuance. Device Activity uses whole date components: the registered interval starts one second earlier and rounds the end up, satisfying Apple's fifteen-minute minimum while never ending before the stored expiry. Date components include a UTC timezone and full date to handle midnight and daylight-saving transitions. OS delivery itself is not exact. Expiry callbacks recompute shields from current grants, preserving any newer window when an old callback arrives. Foreground reconciliation and the next solve prune old monitor registrations.

**Persistence and concurrency.** Store JSON in one App Group. `flock` on a separate lock file serializes full read-modify-write transactions across processes, including the resulting ManagedSettings update. Atomic replacement protects the state file. A corrupt file throws; it does not reset selections or clear existing system shields. Device Activity calls happen outside this lock because Apple documents that monitoring can immediately invoke extension callbacks. Plain UserDefaults or one actor per process would not give this ordering.

**Design direction.** Quiet calculation sheet with one prominent multiplication expression; rounded system type makes it approachable without a gamified feed. Palette: paper blue `#F2F7FF`, ink `#21385C`, action blue `#2E59C2`, muted slate `#5C6E8C`, dividers `#CCD9F0`, with matching dark variants. Left-align setup and app rows; center the arithmetic and answer. The home screen shows app state and a compact unlock action. Avoid streaks, rewards, decorative dashboards, or scroll-inducing content. The icon is drawn reproducibly from Swift/AppKit as doorposts around a multiplication sign.

**Verification approach.** Foundation-only Swift package checks products, expiry boundaries, app isolation, stale grants, persistence, corruption, and concurrent writes. XCUITest drives a wrong answer, a correct answer, cancellation, and early locking through the same challenge UI in an explicit Debug preview. Preview is labeled and never constructs the real Screen Time service. It cannot prove system enforcement. The physical test matrix remains a separate acceptance gate.

**Initial test failure.** `XCTAssertNoThrow` around the mutation inside `DispatchQueue.concurrentPerform` caused Swift to infer a throwing worker closure, which that API rejects. Replaced it with explicit `do/catch` and `XCTFail`. This was a harness compile issue; tests had not executed yet. The first simulator app build succeeded, then notification delegate isolation/import annotations were tightened to remove Swift concurrency warnings.

**Primary references consulted.**

- [Individual authorization and Screen Time APIs](https://developer.apple.com/videos/play/wwdc2022/110336/)
- [Direct opening from a shield action](https://developer.apple.com/documentation/managedsettings/shieldactionresponse/openparentalcontrolsapp)
- [Shield configuration](https://developer.apple.com/documentation/managedsettingsui/shieldconfiguration)
- [Minimum Device Activity interval](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort)
- [Starting monitoring and immediate callbacks](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/startmonitoring(_:during:events:))
- [Interval-end callback semantics](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidend(for:))
- [Provisioning Family Controls](https://developer.apple.com/documentation/xcode/configuring-family-controls)

## 2026-09-08 — Build and visual verification

**Passed:** 11 core XCTest cases (`./scripts/test.sh`), including absolute schedule bounds across midnight and both Toronto DST transitions; 2 XCUITest flows on the iPhone 17 Pro / iOS 26.3.1 simulator; Debug simulator build of all four targets; unsigned Release build for physical iPhone architecture. The final UI suite also passed after the project configuration fixes. No Swift compile warnings remain. Xcode emits its informational App Intents metadata-skipped warning because the project has no App Intents dependency.

**Inspected:** light home screen, calculation screen, success/countdown, dark home screen, and source-generated icon. Saved screenshots in `docs/screenshots/`. Normal unsigned simulator launch correctly reports missing App Group storage; the separate, clearly labeled preview runs without real Screen Time access. Do not interpret a preview's success message as iOS enforcement.

**Icon failure and fix:** the initial three-channel `NSBitmapImageRep` did not give AppKit a working drawing context, resulting in an all-black icon despite successful compilation. Replaced it with an explicit RGB Core Graphics context (`noneSkipLast`), then created the PNG from that context. Viewed the regenerated image and verified it has no alpha channel.

**XcodeGen trap:** setting `TARGETED_DEVICE_FAMILY` only at project level did not override XcodeGen's generated per-target default (`1,2`). This produced a Release orientation warning and an unintended universal app. Set the property explicitly on the app, extension template, and UI test target. Inspected the final built app and all three extension Info.plists: each has `UIDeviceFamily = [1]`, and each resolves the same App Group. Final Release build passes without the orientation warning. Likewise, bundle/App Group defaults live before `Local.xcconfig` so personal overrides are effective.

**Still unverified:** actual individual authorization and app tokens, shield appearance on another app, notification handoff from the extension, direct handoff with the new SDK, and background re-blocking after 15 minutes. The paired phone needs compatible Xcode device tooling and a user-selected signing team. No provisioning request, install, or distribution was performed. Full checklist is in `docs/device-testing.md`.

## 2026-09-08 — Development signing and bundle identifiers

Configured an authorized development team and unique namespace in the ignored `Config/Local.xcconfig`. All extension identifiers derive from the main bundle ID; all targets share the same App Group. The simulator launcher reads the actual built app's identifier from its Info.plist instead of hardcoding it. Account details and local identifiers are kept outside the public repository.

Verified resolved build settings for all targets. A signed Debug iPhone build with `-allowProvisioningUpdates` succeeded. Inspected the code-signing entitlements and embedded provisioning profile of the app and each of its three extensions: Family Controls is true and the team and App Group match. Shell syntax and whitespace checks passed. No core behavior changed, so the existing core/UI suites were not repeated. Device installation and enforcement testing remain unverified; that SDK builds the notification/manual handoff.

## 2026-09-08 — Preparing the public repository

The request to make the project reusable publicly supersedes retaining personal setup details in tracked history. Sanitized local paths, account identifiers, and private repository references from the existing design notes while preserving technical decisions and actual verification. The original notes remain locally in ignored `.local/` for continuity. No private version has been committed or pushed.

Public config defaults to an example bundle ID; developers set their own team and unique IDs in `Config/Local.xcconfig`. Existing local signing overrides are preserved. Simulator scripts now choose an available iPhone running iOS 17+ rather than assuming a specific UDID. The generator uses macOS's built-in grep so a fresh checkout does not require ripgrep. An unedited signing template fails with instructions before requesting provisioning.

The README embeds the existing, inspected simulator screenshots in a three-step walkthrough, labels them as previews, explains setup and OS handoff constraints, and links the physical-device checklist. Added the MIT license and a contributor guide. Expanded ignore rules to cover Xcode user state, generated/build artifacts, signing material, credentials, and local notes. Validation and publishing results follow below.

**Public-checkout validation.** Exported only staged files into a clean temporary directory, without local signing overrides or previous build outputs. All 11 core tests and both simulator UI tests passed there; the latter built the app and all extensions under the public example namespace using automatic simulator selection. Checked selection behavior for running/newest/explicit devices and rejected unsupported or missing devices. Confirmed that missing or unedited signing configuration fails with setup instructions before provisioning. Existing private signing settings still resolve correctly in the original checkout.

**Publication audit.** Inspected all 44 staged files for personal paths, account and device identifiers, credential patterns, signing material, and generated/build files. Checked representative ignore rules and all local README links. The public screenshots use only sample app data. The repository is prepared for `nuynait/screen-time-enhancement` under the MIT license, with the complete app, extensions, tests, scripts, assets, and documentation. Physical-device enforcement remains explicitly unverified.
